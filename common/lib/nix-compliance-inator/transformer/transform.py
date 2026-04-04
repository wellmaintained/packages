"""Transform Nix metadata JSON into CycloneDX 1.6 SBOM.

Reads buildtime-dependencies.json and runtime-dependencies.json produced by
the Nix metadata extraction phase, joins them, and outputs a valid CycloneDX
1.6 JSON document.

Usage:
    python transform.py --buildtime buildtime-dependencies.json \
                        --runtime runtime-dependencies.json \
                        --name my-app-closure \
                        [--output sbom.cdx.json]
"""

import argparse
import base64
import json
import logging
import re
import sys
from decimal import Decimal

from cyclonedx.model import (
    ExternalReference,
    ExternalReferenceType,
    HashAlgorithm,
    HashType,
    Property,
    XsUri,
)
from cyclonedx.model.bom import Bom
from cyclonedx.model.component import (
    Component,
    ComponentEvidence,
    ComponentScope,
    ComponentType,
    Diff,
    Patch,
    PatchClassification,
    Pedigree,
)
from cyclonedx.model.component_evidence import (
    AnalysisTechnique,
    Identity,
    IdentityField,
    Method,
)
from cyclonedx.model.dependency import Dependency
from cyclonedx.model.license import DisjunctiveLicense
from cyclonedx.model.vulnerability import BomTarget, Vulnerability, VulnerabilitySource
from cyclonedx.output.json import JsonV1Dot6
from packageurl import PackageURL

logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s", stream=sys.stderr)
logger = logging.getLogger("nix-compliance-inator")

TOOL_NAME = "nix-compliance-inator"
TOOL_VERSION = "0.2.0"

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

        # Deduplicate by Nix identity (name@version)
        dedup_key = f"{name}@{version}"
        if dedup_key in seen_purls:
            continue
        seen_purls.add(dedup_key)

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
    """Build ExternalReference list from src URLs, homepage, and changelog."""
    refs = []
    meta = dep.get("meta", {})

    # Source URLs with hashes
    src = dep.get("src", {})
    if isinstance(src, str):
        # pyproject.nix packages: src is a store path string, not a dict
        src_urls = []
        src_hash = ""
    else:
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
            hash_content = src_hash
            hash_alg = HashAlgorithm.SHA_256
            # Strip SRI prefix if present (e.g. sha256-..., sha512-...)
            sri_prefixes = {
                "sha256-": HashAlgorithm.SHA_256,
                "sha512-": HashAlgorithm.SHA_512,
                "sha384-": HashAlgorithm.SHA_384,
                "sha1-": HashAlgorithm.SHA_1,
                "md5-": HashAlgorithm.MD5,
            }
            for prefix, alg in sri_prefixes.items():
                if hash_content.startswith(prefix):
                    hash_content = hash_content[len(prefix):]
                    hash_alg = alg
                    break
            # Convert base64 to hex (SRI hashes are base64-encoded)
            try:
                decoded = base64.b64decode(hash_content)
                hash_content = decoded.hex()
            except Exception:
                pass  # already hex or unknown format
            try:
                ext.hashes.add(
                    HashType(alg=hash_alg, content=hash_content)
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

    # Changelog / release notes
    changelog = meta.get("changelog")
    if changelog:
        refs.append(
            ExternalReference(
                type=ExternalReferenceType.RELEASE_NOTES,
                url=XsUri(str(changelog)),
            )
        )

    return refs


def generate_cpe(dep: dict) -> str | None:
    """Generate a CPE 2.3 string from Nix package identifiers.

    Strategy 1: Use preformatted identifiers.cpe string if available.
    Strategy 2: Build from cpeParts (product required, vendor defaults to product).
    Returns None if no CPE data available.
    """
    meta = dep.get("meta", {})
    identifiers = meta.get("identifiers")
    if not identifiers:
        return None

    # Strategy 1: preformatted CPE string
    cpe = identifiers.get("cpe")
    if cpe:
        return cpe

    # Strategy 2: build from cpeParts
    cpe_parts = identifiers.get("cpeParts")
    if cpe_parts:
        product = cpe_parts.get("product")
        if not product:
            return None
        vendor = cpe_parts.get("vendor", product)
        version = dep.get("version", "*")
        return f"cpe:2.3:a:{vendor}:{product}:{version}:*:*:*:*:*:*:*"

    return None


# -- Upstream ecosystem detection --

# Regex to match Python wheel filenames:
# e.g., "django-5.2.11-py3-none-any.whl", "cryptography-46.0.5-cp313-cp313-linux_x86_64.whl"
WHEEL_RE = re.compile(r"[\w.-]+-[\w.]+-(?:py2|py3|cp\d+)[\w.-]*\.whl$")


def detect_upstream_ecosystem(
    dep: dict,
) -> tuple[str, str, str, int, str] | None:
    """Detect the upstream package ecosystem from Nix dependency metadata.

    Returns (ecosystem_type, name, version, confidence_percent, evidence_reason)
    or None. The evidence_reason describes how the ecosystem was determined.

    Detection tiers:
      - Tier 0: Nix-native ecosystem marker (from buildtime-dependencies.nix)
      - Tier A: URL-based signals (pypi.org, crates.io, etc.)
    """
    name = dep.get("pname") or dep.get("name", "")
    version = dep.get("version", "")
    meta = dep.get("meta", {})
    src = dep.get("src", {})

    # Tier 0: Nix-native ecosystem marker (highest confidence)
    nix_ecosystem = dep.get("ecosystem")
    if nix_ecosystem:
        return (nix_ecosystem, name, version, 99, "nix ecosystem attribute")

    # Collect URLs to check
    homepage = meta.get("homepage", "")
    if isinstance(homepage, list):
        homepage = homepage[0] if homepage else ""
    homepage = str(homepage)

    src_urls = []
    if isinstance(src, dict):
        src_urls = src.get("urls", [])
    elif isinstance(src, str):
        src_urls = [src]

    # A1: homepage contains pypi.org
    if "pypi.org" in homepage:
        return ("pypi", name, version, 95, homepage)

    # A2: src URL contains files.pythonhosted.org
    for url in src_urls:
        if "files.pythonhosted.org" in url:
            return ("pypi", name, version, 95, url)

    # A3: src path/URL matches Python wheel filename
    for url in src_urls:
        if WHEEL_RE.search(url):
            return ("pypi", name, version, 90, url)

    # A4: src URL contains proxy.golang.org
    for url in src_urls:
        if "proxy.golang.org" in url:
            return ("golang", name, version, 95, url)

    # A5: homepage matches pkg.go.dev or golang.org/x/
    if "pkg.go.dev" in homepage or "golang.org/x/" in homepage:
        return ("golang", name, version, 90, homepage)

    # A6: src URL contains crates.io
    for url in src_urls:
        if "crates.io" in url or "static.crates.io" in url:
            return ("cargo", name, version, 95, url)

    # A7: src URL contains registry.npmjs.org
    for url in src_urls:
        if "registry.npmjs.org" in url:
            return ("npm", name, version, 95, url)

    # A8: src URL contains hackage.haskell.org
    for url in src_urls:
        if "hackage.haskell.org" in url:
            return ("hackage", name, version, 95, url)

    # A9: src URL contains rubygems.org
    for url in src_urls:
        if "rubygems.org" in url:
            return ("gem", name, version, 95, url)

    # A10: src URL contains cpan.org or cpan.metacpan.org
    for url in src_urls:
        if "cpan.org" in url or "cpan.metacpan.org" in url:
            return ("cpan", name, version, 95, url)

    return None


def build_component(
    dep: dict,
) -> tuple[Component, tuple[str, str, str, int, str] | None]:
    """Build a CycloneDX Component from a joined dependency entry.

    When an upstream ecosystem is detected, the component PURL uses the
    upstream type (e.g., pkg:pypi/django@5.2.11) for scanner compatibility.
    Nix-specific metadata is captured in component properties, pedigree,
    and evidence.

    Returns (component, ecosystem_info).
    """
    name = dep.get("pname") or dep.get("name", "unknown")
    version = dep.get("version", "")
    store_path = dep.get("storePath", "") or dep.get("path", "")
    meta = dep.get("meta", {})

    bom_ref = make_bom_ref(store_path, name, version)

    # Ecosystem detection
    ecosystem_info = detect_upstream_ecosystem(dep)

    # PURL: use upstream ecosystem type when detected, otherwise pkg:nix/
    if ecosystem_info:
        eco_type, eco_name, eco_version, confidence, reason = ecosystem_info
        purl = PackageURL(type=eco_type, name=eco_name, version=eco_version or None)
    else:
        purl = PackageURL(type="nix", name=name, version=version or None)

    # CPE: only from existing meta.identifiers (system libs)
    cpe = generate_cpe(dep)

    # Component type: APPLICATION if it has a main executable, otherwise LIBRARY
    comp_type = (ComponentType.APPLICATION
                 if meta.get("mainProgram")
                 else ComponentType.LIBRARY)

    component = Component(
        name=name,
        version=version,
        type=comp_type,
        scope=ComponentScope.REQUIRED,
        purl=purl,
        bom_ref=bom_ref,
        cpe=cpe,
    )

    # Evidence: document how the PURL was determined
    if ecosystem_info:
        eco_type, _, _, confidence, reason = ecosystem_info
        technique = (AnalysisTechnique.MANIFEST_ANALYSIS
                     if confidence in (99, 80)
                     else AnalysisTechnique.OTHER)
        component.evidence = ComponentEvidence(
            identity=[Identity(
                field=IdentityField.PURL,
                confidence=Decimal(confidence) / Decimal(100),
                concluded_value=str(purl),
                methods=[Method(
                    technique=technique,
                    confidence=Decimal(confidence) / Decimal(100),
                    value=reason,
                )],
            )],
        )
    else:
        component.evidence = ComponentEvidence(
            identity=[Identity(
                field=IdentityField.PURL,
                confidence=Decimal(1),
                concluded_value=str(purl),
                methods=[Method(
                    technique=AnalysisTechnique.MANIFEST_ANALYSIS,
                    confidence=Decimal(1),
                    value=store_path or "nix store path",
                )],
            )],
        )

    # Nix metadata properties
    if store_path:
        component.properties.add(Property(name="nix:storePath", value=store_path))
    component.properties.add(Property(name="nix:packaged", value="true"))

    # Maintainer properties
    for i, maintainer in enumerate(meta.get("maintainers", [])):
        prefix = f"nix:maintainer:{i}"
        if maintainer.get("name"):
            component.properties.add(Property(name=f"{prefix}:name", value=maintainer["name"]))
        if maintainer.get("email"):
            component.properties.add(Property(name=f"{prefix}:email", value=maintainer["email"]))
        if maintainer.get("github"):
            component.properties.add(Property(name=f"{prefix}:github", value=maintainer["github"]))

    # Pedigree: Nix patches applied to the package
    nix_patches = dep.get("patches", [])
    if nix_patches:
        cdx_patches = []
        for patch_path in nix_patches:
            cdx_patches.append(
                Patch(
                    type=PatchClassification.UNOFFICIAL,
                    diff=Diff(url=XsUri(patch_path)),
                )
            )
        component.pedigree = Pedigree(patches=cdx_patches)

    # Log mapping decision
    if ecosystem_info:
        eco_type, _, _, confidence, _ = ecosystem_info
        logger.info(
            "upstream mapping: %s@%s → pkg:%s/%s@%s (confidence: %d%%)",
            name, version, eco_type, name, version, confidence,
        )
    else:
        logger.info(
            "upstream mapping: %s@%s → pkg:nix/%s@%s (unmapped)",
            name, version, name, version,
        )

    # Description
    description = meta.get("description")
    if description:
        component.description = str(description)

    # Licenses
    for lic in extract_licenses(meta):
        component.licenses.add(lic)

    # External references (includes changelog)
    for ext_ref in extract_external_references(dep):
        component.external_references.add(ext_ref)

    return component, ecosystem_info


def build_bom(
    buildtime: list[dict],
    runtime: list[str],
    root_name: str,
    references: dict[str, dict] | None = None,
) -> Bom:
    """Build a CycloneDX 1.6 BOM from Nix metadata.

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
    ecosystem_counts: dict[str, int] = {}
    unmapped_count = 0
    nvd_source = VulnerabilitySource(name="NVD", url=XsUri("https://nvd.nist.gov/"))

    for dep in joined:
        component, eco_info = build_component(dep)
        bom.components.add(component)
        store_path = dep.get("storePath", "") or dep.get("path", "")
        if store_path:
            path_to_bom_ref[store_path] = component.bom_ref

        # Track mapping statistics
        if eco_info:
            ecosystem_counts[eco_info[0]] = ecosystem_counts.get(eco_info[0], 0) + 1
        else:
            unmapped_count += 1

        # Emit knownVulnerabilities as BOM-level vulnerabilities
        for cve_id in dep.get("meta", {}).get("knownVulnerabilities", []):
            vuln = Vulnerability(
                id=cve_id,
                source=nvd_source,
                description="Known vulnerability flagged by Nix (meta.knownVulnerabilities)",
            )
            if store_path and store_path in path_to_bom_ref:
                vuln.affects.add(BomTarget(ref=path_to_bom_ref[store_path]))
            bom.vulnerabilities.add(vuln)

    mapped_count = sum(ecosystem_counts.values())
    total_count = mapped_count + unmapped_count
    parts = [f"{eco}: {count}" for eco, count in sorted(ecosystem_counts.items())]
    logger.info(
        "ecosystem mapping summary: %d/%d components mapped (%s, unmapped: %d)",
        mapped_count, total_count, ", ".join(parts) if parts else "none", unmapped_count,
    )

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
    """Main transform: read JSON files, produce CycloneDX 1.6 JSON string."""
    with open(buildtime_path) as f:
        buildtime = json.load(f)

    with open(runtime_path) as f:
        runtime = json.load(f)

    references = None
    if references_path:
        with open(references_path) as f:
            references = json.load(f)

    bom = build_bom(buildtime, runtime, root_name, references)

    outputter = JsonV1Dot6(bom)
    return outputter.output_as_string()


def main():
    parser = argparse.ArgumentParser(
        description="Transform Nix metadata JSON into CycloneDX 1.6 SBOM"
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
