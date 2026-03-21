"""Transform Nix metadata JSON into CycloneDX 1.7 SBOM.

Reads buildtime-dependencies.json and runtime-dependencies.json produced by
the Nix metadata extraction phase, joins them, and outputs a valid CycloneDX
1.7 JSON document.

Usage:
    python transform.py --buildtime buildtime-dependencies.json \
                        --runtime runtime-dependencies.json \
                        --name my-app-closure \
                        [--output sbom.cdx.json]
"""

import argparse
import json
import re
import sys

from cyclonedx.model import (
    ExternalReference,
    ExternalReferenceType,
    HashAlgorithm,
    HashType,
    XsUri,
)
from cyclonedx.model.bom import Bom
from cyclonedx.model.component import Component, ComponentScope, ComponentType
from cyclonedx.model.dependency import Dependency
from cyclonedx.model.license import DisjunctiveLicense
from cyclonedx.output.json import JsonV1Dot7
from packageurl import PackageURL

TOOL_NAME = "nix-cyclonedx-inator"
TOOL_VERSION = "0.1.0"

# Regex to parse name and version from a Nix store path like:
# /nix/store/abc123-package-name-1.2.3
STORE_PATH_RE = re.compile(
    r"/nix/store/[a-z0-9]{32}-(?P<name>.+?)-(?P<version>\d[^-]*)$"
)

# Store paths with these output suffixes are not useful SBOM components.
EXCLUDED_SUFFIXES = ("-doc", "-man", "-info", "-devdoc")


def parse_store_path(path: str) -> tuple[str, str]:
    """Extract (name, version) from a Nix store path string.

    Returns (name, "") if no version can be parsed.
    """
    m = STORE_PATH_RE.match(path)
    if m:
        return m.group("name"), m.group("version")
    # Fallback: strip the hash prefix and try to split
    basename = path.rsplit("/", 1)[-1]
    # Remove the 32-char hash prefix + dash
    if len(basename) > 33 and basename[32] == "-":
        basename = basename[33:]
    return basename, ""


def join_dependencies(
    buildtime: list[dict], runtime: list[str]
) -> list[dict]:
    """Join runtime store paths with buildtime metadata.

    For each runtime store path, find the matching buildtime entry.
    Falls back to parsing name/version from the store path if no
    buildtime metadata is found.
    """
    # Index buildtime deps by output path for O(1) lookup.
    # Our buildtime JSON uses "path" as the store path key.
    bt_by_path = {}
    for dep in buildtime:
        if "path" in dep:
            bt_by_path[dep["path"]] = dep

    joined = []
    seen_purls = set()

    for store_path in runtime:
        # Skip excluded outputs
        if any(store_path.endswith(s) for s in EXCLUDED_SUFFIXES):
            continue

        if store_path in bt_by_path:
            entry = dict(bt_by_path[store_path])
            entry.setdefault("storePath", store_path)
        else:
            # Fallback: parse from store path
            name, version = parse_store_path(store_path)
            entry = {"name": name, "version": version, "storePath": store_path}

        # Skip entries without a version (can't produce meaningful PURL)
        name = entry.get("pname") or entry.get("name", "")
        version = entry.get("version", "")
        if not version or not name:
            continue

        # Deduplicate by PURL
        purl_key = f"pkg:nix/{name}@{version}"
        if purl_key in seen_purls:
            continue
        seen_purls.add(purl_key)

        joined.append(entry)

    return joined


def make_bom_ref(store_path: str, name: str, version: str) -> str:
    """Create a bom-ref from the store path hash, name, and version.

    Mimics bombon's format: <hash>-<name>-<version>
    """
    basename = store_path.rsplit("/", 1)[-1] if "/" in store_path else store_path
    # Remove /nix/store/ prefix hash if present
    if len(basename) > 33 and basename[32] == "-":
        hash_prefix = basename[:32]
        return f"{hash_prefix}-{name}-{version}"
    return f"{name}-{version}"


def extract_licenses(meta: dict) -> list[DisjunctiveLicense]:
    """Extract SPDX license IDs from Nix meta.license."""
    licenses_data = meta.get("license")
    if not licenses_data:
        return []

    if isinstance(licenses_data, dict):
        licenses_data = [licenses_data]

    result = []
    for lic in licenses_data:
        if isinstance(lic, dict):
            spdx_id = lic.get("spdxId")
            if spdx_id:
                try:
                    result.append(DisjunctiveLicense(id=spdx_id))
                except Exception:
                    pass
    return result


def extract_external_references(
    dep: dict,
) -> list[ExternalReference]:
    """Build ExternalReference list from src URLs and homepage."""
    refs = []
    meta = dep.get("meta", {})

    # Source URLs with hashes
    src = dep.get("src", {})
    src_urls = src.get("urls", [])
    src_hash = src.get("hash", "") or src.get("outputHash", "")

    for url in src_urls:
        if not url:
            continue
        ext = ExternalReference(
            type=ExternalReferenceType.DISTRIBUTION,
            url=XsUri(url),
        )
        if src_hash:
            # Nix uses SHA-256 for source hashes (SRI format: sha256-... or hex)
            hash_content = src_hash
            # Strip SRI prefix if present
            if hash_content.startswith("sha256-"):
                hash_content = hash_content[7:]
            try:
                ext.hashes.add(
                    HashType(alg=HashAlgorithm.SHA_256, content=hash_content)
                )
            except Exception:
                pass
        refs.append(ext)

    # Homepage
    homepage = meta.get("homepage")
    if homepage:
        if isinstance(homepage, list):
            homepage = homepage[0] if homepage else None
        if homepage:
            refs.append(
                ExternalReference(
                    type=ExternalReferenceType.WEBSITE,
                    url=XsUri(str(homepage)),
                )
            )

    return refs


def build_component(dep: dict) -> Component:
    """Build a CycloneDX Component from a joined dependency entry."""
    name = dep.get("pname") or dep.get("name", "unknown")
    version = dep.get("version", "")
    store_path = dep.get("storePath", "") or dep.get("path", "")
    meta = dep.get("meta", {})

    purl = PackageURL(type="nix", name=name, version=version or None)
    bom_ref = make_bom_ref(store_path, name, version)

    component = Component(
        name=name,
        version=version,
        type=ComponentType.APPLICATION,
        scope=ComponentScope.REQUIRED,
        purl=purl,
        bom_ref=bom_ref,
    )

    # Description
    description = meta.get("description")
    if description:
        component.description = str(description)

    # Licenses
    for lic in extract_licenses(meta):
        component.licenses.add(lic)

    # External references
    for ext_ref in extract_external_references(dep):
        component.external_references.add(ext_ref)

    return component


def build_bom(
    buildtime: list[dict],
    runtime: list[str],
    root_name: str,
    references: dict[str, dict] | None = None,
) -> Bom:
    """Build a CycloneDX 1.7 BOM from Nix metadata.

    If references is provided (from nix path-info --recursive), use it for
    runtime reference edges. Otherwise fall back to buildtime dependency edges.
    """
    bom = Bom()

    # Tool metadata
    tool = Component(
        name=TOOL_NAME,
        version=TOOL_VERSION,
        type=ComponentType.APPLICATION,
        description="Nix CycloneDX SBOM generator",
    )
    bom.metadata.tools.components.add(tool)

    # Root component
    bom.metadata.component = Component(
        name=root_name,
        type=ComponentType.APPLICATION,
        purl=PackageURL(type="nix", name=root_name),
    )

    # Join and build components, tracking path-to-bom_ref for dependency wiring
    joined = join_dependencies(buildtime, runtime)
    path_to_bom_ref: dict[str, str] = {}
    components_by_path: dict[str, Component] = {}

    for dep in joined:
        component = build_component(dep)
        bom.components.add(component)
        store_path = dep.get("storePath", "") or dep.get("path", "")
        if store_path:
            path_to_bom_ref[store_path] = component.bom_ref
            components_by_path[store_path] = component

    root_dep = Dependency(ref=bom.metadata.component.bom_ref)

    if references:
        # Use runtime reference edges from nix path-info
        for store_path, bom_ref in path_to_bom_ref.items():
            dep_node = Dependency(ref=bom_ref)
            ref_entry = references.get(store_path, {})
            for ref_path in ref_entry.get("references", []):
                if ref_path in path_to_bom_ref and ref_path != store_path:
                    dep_node.dependencies.add(
                        Dependency(ref=path_to_bom_ref[ref_path])
                    )
            bom.dependencies.add(dep_node)
            root_dep.dependencies.add(Dependency(ref=bom_ref))
    else:
        # Fall back to buildtime dependency edges
        bt_by_path = {dep["path"]: dep for dep in buildtime if "path" in dep}

        for store_path, bom_ref in path_to_bom_ref.items():
            dep_node = Dependency(ref=bom_ref)
            bt_entry = bt_by_path.get(store_path, {})
            for child_path in bt_entry.get("dependencies", []):
                if child_path in path_to_bom_ref:
                    dep_node.dependencies.add(
                        Dependency(ref=path_to_bom_ref[child_path])
                    )
            bom.dependencies.add(dep_node)
            root_dep.dependencies.add(Dependency(ref=bom_ref))

    bom.dependencies.add(root_dep)

    return bom


def transform(
    buildtime_path: str,
    runtime_path: str,
    root_name: str,
    references_path: str | None = None,
) -> str:
    """Main transform: read JSON files, produce CycloneDX 1.7 JSON string."""
    with open(buildtime_path) as f:
        buildtime = json.load(f)

    with open(runtime_path) as f:
        runtime = json.load(f)

    references = None
    if references_path:
        with open(references_path) as f:
            references = json.load(f)

    bom = build_bom(buildtime, runtime, root_name, references)

    outputter = JsonV1Dot7(bom)
    return outputter.output_as_string()


def main():
    parser = argparse.ArgumentParser(
        description="Transform Nix metadata JSON into CycloneDX 1.7 SBOM"
    )
    parser.add_argument(
        "--buildtime",
        required=True,
        help="Path to buildtime-dependencies.json",
    )
    parser.add_argument(
        "--runtime",
        required=True,
        help="Path to runtime-dependencies.json",
    )
    parser.add_argument(
        "--name",
        required=True,
        help="Name of the root component (e.g. my-app-closure)",
    )
    parser.add_argument(
        "--references",
        help="Path to runtime-reference-graph.json (from nix path-info)",
    )
    parser.add_argument(
        "--output",
        "-o",
        help="Output file path (default: stdout)",
    )

    args = parser.parse_args()
    result = transform(args.buildtime, args.runtime, args.name, args.references)

    # Pretty-print the JSON
    formatted = json.dumps(json.loads(result), indent=2)

    if args.output:
        with open(args.output, "w") as f:
            f.write(formatted)
            f.write("\n")
    else:
        print(formatted)


if __name__ == "__main__":
    main()
