"""Tests for the Nix-to-CycloneDX transformer."""

import json
import os
import tempfile

import pytest

import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from cyclonedx.model.component import ComponentType, PatchClassification
from cyclonedx.model import ExternalReferenceType

from transform import (
    build_bom,
    build_component,
    detect_upstream_ecosystem,
    extract_external_references,
    extract_licenses,
    generate_cpe,
    join_dependencies,
    make_bom_ref,
    parse_store_path,
    transform,
)

# -- Fixtures --

SAMPLE_BUILDTIME = [
    {
        "name": "libunistring-1.4.1",
        "pname": "libunistring",
        "version": "1.4.1",
        "path": "/nix/store/1xakvg5jqmaiawwk0n1sbhvsvrdya512-libunistring-1.4.1",
        "outputName": "out",
        "dependencies": [],
        "meta": {
            "description": "Unicode string library",
            "homepage": "https://www.gnu.org/software/libunistring/",
            "license": [{"spdxId": "LGPL-3.0-or-later"}],
            "identifiers": {
                "cpe": "cpe:2.3:a:gnu:libunistring:1.4.1:*:*:*:*:*:*:*",
            },
        },
        "src": {
            "urls": [
                "https://ftpmirror.gnu.org/libunistring/libunistring-1.4.1.tar.gz"
            ],
            "hash": "sha256-ElQq12GUcO/ZWmIxdNzUs2TySDyvcIxr7oN8tTpUy50=",
        },
        "patches": [],
    },
    {
        "name": "bash-5.2p26",
        "pname": "bash",
        "version": "5.2p26",
        "path": "/nix/store/abc12345678901234567890123456789-bash-5.2p26",
        "outputName": "out",
        "dependencies": [
            "/nix/store/1xakvg5jqmaiawwk0n1sbhvsvrdya512-libunistring-1.4.1",
        ],
        "meta": {
            "description": "GNU Bourne-Again Shell",
            "homepage": "https://www.gnu.org/software/bash/",
            "license": [{"spdxId": "GPL-3.0-or-later"}],
        },
        "patches": [],
    },
    {
        "name": "no-version-pkg",
        "pname": "no-version-pkg",
        "version": "",
        "path": "/nix/store/zzz12345678901234567890123456789-no-version-pkg",
        "outputName": "out",
        "dependencies": [],
        "meta": {},
        "patches": [],
    },
]

SAMPLE_RUNTIME = [
    "/nix/store/1xakvg5jqmaiawwk0n1sbhvsvrdya512-libunistring-1.4.1",
    "/nix/store/abc12345678901234567890123456789-bash-5.2p26",
    "/nix/store/def12345678901234567890123456789-unknown-runtime-2.0",
    "/nix/store/zzz12345678901234567890123456789-no-version-pkg",
    "/nix/store/ghi12345678901234567890123456789-somepkg-1.0-doc",
]


# -- parse_store_path tests --


class TestParseStorePath:
    def test_standard_path(self):
        name, version = parse_store_path(
            "/nix/store/1xakvg5jqmaiawwk0n1sbhvsvrdya512-libunistring-1.4.1"
        )
        assert name == "libunistring"
        assert version == "1.4.1"

    def test_version_with_suffix(self):
        name, version = parse_store_path(
            "/nix/store/abc12345678901234567890123456789-bash-5.2p26"
        )
        assert name == "bash"
        assert version == "5.2p26"

    def test_no_version(self):
        name, version = parse_store_path(
            "/nix/store/abc12345678901234567890123456789-some-package"
        )
        assert name == "some-package"
        assert version == ""


# -- join_dependencies tests --


class TestJoinDependencies:
    def test_joins_runtime_with_buildtime(self):
        joined = join_dependencies(SAMPLE_BUILDTIME, SAMPLE_RUNTIME)
        names = {d.get("pname") or d.get("name") for d in joined}
        assert "libunistring" in names
        assert "bash" in names

    def test_fallback_for_unknown_runtime(self):
        joined = join_dependencies(SAMPLE_BUILDTIME, SAMPLE_RUNTIME)
        names = {d.get("pname") or d.get("name") for d in joined}
        assert "unknown-runtime" in names

    def test_excludes_doc_outputs(self):
        joined = join_dependencies(SAMPLE_BUILDTIME, SAMPLE_RUNTIME)
        paths = {d.get("storePath", "") for d in joined}
        assert not any(p.endswith("-doc") for p in paths)

    def test_excludes_versionless(self):
        joined = join_dependencies(SAMPLE_BUILDTIME, SAMPLE_RUNTIME)
        names = {d.get("pname") or d.get("name") for d in joined}
        assert "no-version-pkg" not in names

    def test_deduplicates_by_purl(self):
        # Add a duplicate runtime path that maps to same pname/version
        runtime_with_dup = SAMPLE_RUNTIME + [
            "/nix/store/1xakvg5jqmaiawwk0n1sbhvsvrdya512-libunistring-1.4.1"
        ]
        joined = join_dependencies(SAMPLE_BUILDTIME, runtime_with_dup)
        libunistring_count = sum(
            1
            for d in joined
            if (d.get("pname") or d.get("name")) == "libunistring"
        )
        assert libunistring_count == 1


# -- extract_licenses tests --


class TestExtractLicenses:
    def test_single_license(self):
        meta = {"license": [{"spdxId": "MIT"}]}
        lics = extract_licenses(meta)
        assert len(lics) == 1
        assert lics[0].id == "MIT"

    def test_multiple_licenses(self):
        meta = {"license": [{"spdxId": "MIT"}, {"spdxId": "Apache-2.0"}]}
        lics = extract_licenses(meta)
        assert len(lics) == 2

    def test_no_license(self):
        assert extract_licenses({}) == []

    def test_license_without_spdx(self):
        meta = {"license": [{"fullName": "Some Custom License"}]}
        lics = extract_licenses(meta)
        assert len(lics) == 0

    def test_single_license_dict(self):
        meta = {"license": {"spdxId": "BSD-3-Clause"}}
        lics = extract_licenses(meta)
        assert len(lics) == 1
        assert lics[0].id == "BSD-3-Clause"


# -- extract_external_references tests --


class TestExtractExternalReferences:
    def test_source_url_with_hash(self):
        dep = {
            "src": {
                "urls": ["https://example.com/source.tar.gz"],
                "hash": "deadbeef1234",
            },
            "meta": {},
        }
        refs = extract_external_references(dep)
        assert len(refs) == 1
        assert str(refs[0].url) == "https://example.com/source.tar.gz"

    def test_homepage(self):
        dep = {
            "src": {},
            "meta": {"homepage": "https://example.com"},
        }
        refs = extract_external_references(dep)
        assert len(refs) == 1
        assert str(refs[0].url) == "https://example.com"

    def test_homepage_as_list(self):
        dep = {
            "src": {},
            "meta": {"homepage": ["https://example.com", "https://alt.com"]},
        }
        refs = extract_external_references(dep)
        assert len(refs) == 1
        assert str(refs[0].url) == "https://example.com"

    def test_sri_hash_converted_to_hex(self):
        dep = {
            "src": {
                "urls": ["https://example.com/source.tar.gz"],
                "hash": "sha256-ElQq12GUcO/ZWmIxdNzUs2TySDyvcIxr7oN8tTpUy50=",
            },
            "meta": {},
        }
        refs = extract_external_references(dep)
        assert len(refs) == 1
        hash_obj = list(refs[0].hashes)[0]
        assert hash_obj.content == "12542ad7619470efd95a623174dcd4b364f2483caf708c6bee837cb53a54cb9d"
        assert hash_obj.alg.value == "SHA-256"
        # Must match CycloneDX hex pattern
        import re
        assert re.match(r"^[a-f0-9]{64}$", hash_obj.content)

    def test_hex_hash_passes_through(self):
        dep = {
            "src": {
                "urls": ["https://example.com/source.tar.gz"],
                "hash": "12542ad7619470efd95a623174dcd4b364f2483caf708c6bee837cb53a54cb9d",
            },
            "meta": {},
        }
        refs = extract_external_references(dep)
        assert len(refs) == 1
        hash_obj = list(refs[0].hashes)[0]
        assert len(hash_obj.content) > 0

    def test_sha512_sri_hash(self):
        import base64
        fake_hash_bytes = bytes(range(64))
        b64 = base64.b64encode(fake_hash_bytes).decode()
        dep = {
            "src": {
                "urls": ["https://example.com/source.tar.gz"],
                "hash": f"sha512-{b64}",
            },
            "meta": {},
        }
        refs = extract_external_references(dep)
        assert len(refs) == 1
        hash_obj = list(refs[0].hashes)[0]
        assert hash_obj.content == fake_hash_bytes.hex()
        assert hash_obj.alg.value == "SHA-512"

    def test_no_refs(self):
        dep = {"src": {}, "meta": {}}
        refs = extract_external_references(dep)
        assert len(refs) == 0

    def test_changelog_emitted(self):
        dep = {
            "src": {},
            "meta": {"changelog": "https://github.com/foo/foo/blob/main/CHANGELOG.md"},
        }
        refs = extract_external_references(dep)
        release_notes = [r for r in refs if r.type == ExternalReferenceType.RELEASE_NOTES]
        assert len(release_notes) == 1
        assert str(release_notes[0].url) == "https://github.com/foo/foo/blob/main/CHANGELOG.md"


# -- generate_cpe tests --


class TestGenerateCpe:
    def test_preformatted_cpe_string(self):
        dep = {
            "meta": {
                "identifiers": {
                    "cpe": "cpe:2.3:a:gnu:libunistring:1.4.1:*:*:*:*:*:*:*",
                },
            },
        }
        assert generate_cpe(dep) == "cpe:2.3:a:gnu:libunistring:1.4.1:*:*:*:*:*:*:*"

    def test_cpe_parts_with_vendor(self):
        dep = {
            "pname": "openssl",
            "version": "3.1.4",
            "meta": {
                "identifiers": {
                    "cpeParts": {
                        "product": "openssl",
                        "vendor": "openssl",
                    },
                },
            },
        }
        assert generate_cpe(dep) == "cpe:2.3:a:openssl:openssl:3.1.4:*:*:*:*:*:*:*"

    def test_cpe_parts_without_vendor(self):
        dep = {
            "pname": "curl",
            "version": "8.5.0",
            "meta": {
                "identifiers": {
                    "cpeParts": {
                        "product": "curl",
                    },
                },
            },
        }
        assert generate_cpe(dep) == "cpe:2.3:a:curl:curl:8.5.0:*:*:*:*:*:*:*"

    def test_no_identifiers(self):
        dep = {
            "pname": "somepkg",
            "version": "1.0",
            "meta": {},
        }
        assert generate_cpe(dep) is None

    def test_no_meta(self):
        dep = {"pname": "somepkg", "version": "1.0"}
        assert generate_cpe(dep) is None


# -- build_component tests --


class TestBuildComponent:
    def test_full_component(self):
        dep = SAMPLE_BUILDTIME[0]
        comp, _ = build_component(dep)
        assert comp.name == "libunistring"
        assert comp.version == "1.4.1"
        assert str(comp.purl) == "pkg:nix/libunistring@1.4.1"  # no ecosystem → pkg:nix/
        assert comp.description == "Unicode string library"
        assert len(comp.licenses) == 1
        assert len(comp.external_references) == 2  # source + homepage
        assert comp.cpe == "cpe:2.3:a:gnu:libunistring:1.4.1:*:*:*:*:*:*:*"
        # Nix properties
        props = {p.name: p.value for p in comp.properties}
        assert props["nix:packaged"] == "true"
        assert "nix:storePath" in props

    def test_minimal_component(self):
        dep = {"name": "simple", "version": "1.0", "storePath": "/nix/store/aaa-simple-1.0"}
        comp, _ = build_component(dep)
        assert comp.name == "simple"
        assert comp.version == "1.0"
        assert len(comp.licenses) == 0
        assert str(comp.purl) == "pkg:nix/simple@1.0"


# -- build_bom tests --


class TestBuildBom:
    def test_produces_valid_bom(self):
        bom = build_bom(SAMPLE_BUILDTIME, SAMPLE_RUNTIME, "test-closure")
        assert bom.metadata.component.name == "test-closure"
        assert len(bom.components) > 0
        # Tool metadata
        tool_names = {t.name for t in bom.metadata.tools.components}
        assert "nix-compliance-inator" in tool_names

    def test_spec_version_is_1_6(self):
        bom = build_bom(SAMPLE_BUILDTIME, SAMPLE_RUNTIME, "test-closure")
        from cyclonedx.output.json import JsonV1Dot6

        outputter = JsonV1Dot6(bom)
        output = json.loads(outputter.output_as_string())
        assert output["specVersion"] == "1.6"
        assert output["bomFormat"] == "CycloneDX"

    def test_dependency_graph(self):
        bom = build_bom(SAMPLE_BUILDTIME, SAMPLE_RUNTIME, "test-closure")
        from cyclonedx.output.json import JsonV1Dot6

        outputter = JsonV1Dot6(bom)
        output = json.loads(outputter.output_as_string())

        deps_by_ref = {d["ref"]: d.get("dependsOn", []) for d in output["dependencies"]}

        # Root should depend on all components
        root_ref = output["metadata"]["component"]["bom-ref"]
        assert root_ref in deps_by_ref
        assert len(deps_by_ref[root_ref]) > 0

        # bash depends on libunistring (from the buildtime edge data)
        bash_comp = next(c for c in output["components"] if c["name"] == "bash")
        bash_deps = deps_by_ref.get(bash_comp["bom-ref"], [])
        libunistring_comp = next(c for c in output["components"] if c["name"] == "libunistring")
        assert libunistring_comp["bom-ref"] in bash_deps

        # libunistring is a leaf (no deps in our fixture)
        libunistring_deps = deps_by_ref.get(libunistring_comp["bom-ref"], [])
        assert libunistring_deps == []

    def test_dependency_graph_with_references(self):
        """When references are provided, use runtime edges instead of buildtime."""
        references = {
            "/nix/store/1xakvg5jqmaiawwk0n1sbhvsvrdya512-libunistring-1.4.1": {
                "references": []
            },
            "/nix/store/abc12345678901234567890123456789-bash-5.2p26": {
                "references": [
                    "/nix/store/1xakvg5jqmaiawwk0n1sbhvsvrdya512-libunistring-1.4.1"
                ]
            },
            "/nix/store/def12345678901234567890123456789-unknown-runtime-2.0": {
                "references": [
                    "/nix/store/abc12345678901234567890123456789-bash-5.2p26"
                ]
            },
        }
        bom = build_bom(SAMPLE_BUILDTIME, SAMPLE_RUNTIME, "test-closure", references)
        from cyclonedx.output.json import JsonV1Dot6

        outputter = JsonV1Dot6(bom)
        output = json.loads(outputter.output_as_string())

        deps_by_ref = {d["ref"]: d.get("dependsOn", []) for d in output["dependencies"]}

        unknown_comp = next(c for c in output["components"] if c["name"] == "unknown-runtime")
        bash_comp = next(c for c in output["components"] if c["name"] == "bash")
        unknown_deps = deps_by_ref.get(unknown_comp["bom-ref"], [])
        assert bash_comp["bom-ref"] in unknown_deps

        libunistring_comp = next(c for c in output["components"] if c["name"] == "libunistring")
        bash_deps = deps_by_ref.get(bash_comp["bom-ref"], [])
        assert libunistring_comp["bom-ref"] in bash_deps

        libunistring_deps = deps_by_ref.get(libunistring_comp["bom-ref"], [])
        assert libunistring_deps == []

    def test_dependency_graph_without_references_backwards_compat(self):
        """Without references, falls back to buildtime edges (backwards compat)."""
        bom = build_bom(SAMPLE_BUILDTIME, SAMPLE_RUNTIME, "test-closure")
        from cyclonedx.output.json import JsonV1Dot6

        outputter = JsonV1Dot6(bom)
        output = json.loads(outputter.output_as_string())

        deps_by_ref = {d["ref"]: d.get("dependsOn", []) for d in output["dependencies"]}

        bash_comp = next(c for c in output["components"] if c["name"] == "bash")
        libunistring_comp = next(c for c in output["components"] if c["name"] == "libunistring")
        bash_deps = deps_by_ref.get(bash_comp["bom-ref"], [])
        assert libunistring_comp["bom-ref"] in bash_deps

    def test_components_have_required_fields(self):
        bom = build_bom(SAMPLE_BUILDTIME, SAMPLE_RUNTIME, "test-closure")
        from cyclonedx.output.json import JsonV1Dot6

        outputter = JsonV1Dot6(bom)
        output = json.loads(outputter.output_as_string())

        for comp in output["components"]:
            assert "name" in comp
            assert "version" in comp
            assert "type" in comp
            assert "purl" in comp
            assert "scope" in comp
            assert comp["type"] in ("library", "application")
            assert comp["scope"] == "required"
            # All fixture components are unmapped (GNU/unknown), so pkg:nix/
            assert comp["purl"].startswith("pkg:nix/")


# -- end-to-end transform test --


class TestTransformEndToEnd:
    def test_roundtrip(self):
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False
        ) as bt:
            json.dump(SAMPLE_BUILDTIME, bt)
            bt_path = bt.name

        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False
        ) as rt:
            json.dump(SAMPLE_RUNTIME, rt)
            rt_path = rt.name

        try:
            result = transform(bt_path, rt_path, "test-app-closure")
            output = json.loads(result)

            assert output["specVersion"] == "1.6"
            assert output["bomFormat"] == "CycloneDX"
            assert output["metadata"]["component"]["name"] == "test-app-closure"
            assert len(output["components"]) == 3  # libunistring, bash, unknown-runtime

            libunistring = next(
                c for c in output["components"] if c["name"] == "libunistring"
            )
            assert libunistring["version"] == "1.4.1"
            assert libunistring["description"] == "Unicode string library"
            assert len(libunistring["licenses"]) == 1
            assert libunistring["licenses"][0]["license"]["id"] == "LGPL-3.0-or-later"
            assert libunistring["purl"] == "pkg:nix/libunistring@1.4.1"
        finally:
            os.unlink(bt_path)
            os.unlink(rt_path)

    def test_roundtrip_with_references(self):
        """End-to-end test with runtime reference graph edges."""
        references = {
            "/nix/store/1xakvg5jqmaiawwk0n1sbhvsvrdya512-libunistring-1.4.1": {
                "references": []
            },
            "/nix/store/abc12345678901234567890123456789-bash-5.2p26": {
                "references": [
                    "/nix/store/1xakvg5jqmaiawwk0n1sbhvsvrdya512-libunistring-1.4.1"
                ]
            },
            "/nix/store/def12345678901234567890123456789-unknown-runtime-2.0": {
                "references": [
                    "/nix/store/abc12345678901234567890123456789-bash-5.2p26"
                ]
            },
        }

        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False
        ) as bt:
            json.dump(SAMPLE_BUILDTIME, bt)
            bt_path = bt.name

        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False
        ) as rt:
            json.dump(SAMPLE_RUNTIME, rt)
            rt_path = rt.name

        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False
        ) as rf:
            json.dump(references, rf)
            rf_path = rf.name

        try:
            result = transform(bt_path, rt_path, "test-app-closure", rf_path)
            output = json.loads(result)

            deps_by_ref = {
                d["ref"]: d.get("dependsOn", []) for d in output["dependencies"]
            }

            bash_comp = next(c for c in output["components"] if c["name"] == "bash")
            libunistring_comp = next(
                c for c in output["components"] if c["name"] == "libunistring"
            )
            bash_deps = deps_by_ref.get(bash_comp["bom-ref"], [])
            assert libunistring_comp["bom-ref"] in bash_deps

            unknown_comp = next(
                c for c in output["components"] if c["name"] == "unknown-runtime"
            )
            unknown_deps = deps_by_ref.get(unknown_comp["bom-ref"], [])
            assert bash_comp["bom-ref"] in unknown_deps

            libunistring_deps = deps_by_ref.get(libunistring_comp["bom-ref"], [])
            assert libunistring_deps == []
        finally:
            os.unlink(bt_path)
            os.unlink(rt_path)
            os.unlink(rf_path)

    def test_empty_inputs(self):
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False
        ) as bt:
            json.dump([], bt)
            bt_path = bt.name

        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False
        ) as rt:
            json.dump([], rt)
            rt_path = rt.name

        try:
            result = transform(bt_path, rt_path, "empty-closure")
            output = json.loads(result)
            assert output["specVersion"] == "1.6"
            assert output.get("components", []) == []
        finally:
            os.unlink(bt_path)
            os.unlink(rt_path)


# -- Upstream ecosystem detection fixtures --

SAMPLE_PYPI_RICH = {
    "name": "django-5.2.11",
    "pname": "django",
    "version": "5.2.11",
    "path": "/nix/store/xxx12345678901234567890123456789-django-5.2.11",
    "outputName": "out",
    "dependencies": [],
    "ecosystem": "pypi",
    "meta": {
        "description": "A high-level Python web framework",
        "homepage": "https://pypi.org/project/django/",
        "license": [{"spdxId": "BSD-3-Clause"}],
        "changelog": "https://docs.djangoproject.com/en/5.2/releases/5.2.11/",
        "maintainers": [
            {"name": "Martin Weinelt", "email": "hexa@darmstadt.ccc.de", "github": "mweinelt", "githubId": 131599},
        ],
    },
    "src": {
        "urls": ["https://files.pythonhosted.org/packages/a0/b1/Django-5.2.11.tar.gz"],
        "hash": "sha256-abc123fake=",
    },
    "patches": ["/nix/store/aaa-zoneinfo.patch", "/nix/store/bbb-pythonpath.patch"],
}

SAMPLE_PYPI_VIA_SRC_URL = {
    "name": "boto3-1.40.55",
    "pname": "boto3",
    "version": "1.40.55",
    "path": "/nix/store/yyy12345678901234567890123456789-boto3-1.40.55",
    "outputName": "out",
    "dependencies": [],
    "ecosystem": "pypi",
    "meta": {
        "description": "AWS SDK for Python",
        "homepage": "https://github.com/boto/boto3",
    },
    "src": {
        "urls": ["https://files.pythonhosted.org/packages/a0/b1/boto3-1.40.55.tar.gz"],
    },
    "patches": [],
}

SAMPLE_PYPI_WHEEL = {
    "name": "cryptography-46.0.5",
    "pname": "cryptography",
    "version": "46.0.5",
    "path": "/nix/store/ccc12345678901234567890123456789-cryptography-46.0.5",
    "outputName": "out",
    "dependencies": [],
    "ecosystem": "pypi",
    "src": "/nix/store/ddd12345678901234567890123456789-cryptography-46.0.5-cp313-cp313-linux_x86_64.whl",
    "patches": [],
}

SAMPLE_GO_PACKAGE = {
    "name": "osv-scanner-2.3.3",
    "pname": "osv-scanner",
    "version": "2.3.3",
    "path": "/nix/store/ggg12345678901234567890123456789-osv-scanner-2.3.3",
    "outputName": "out",
    "dependencies": [],
    # No ecosystem field — tests URL-based fallback detection
    "meta": {
        "description": "Vulnerability scanner written in Go",
        "homepage": "https://pkg.go.dev/github.com/google/osv-scanner",
    },
    "patches": [],
}

SAMPLE_CARGO_PACKAGE = {
    "name": "ripgrep-14.1.1",
    "pname": "ripgrep",
    "version": "14.1.1",
    "path": "/nix/store/rrr12345678901234567890123456789-ripgrep-14.1.1",
    "outputName": "out",
    "dependencies": [],
    "ecosystem": "cargo",
    "meta": {},
    "src": {
        "urls": ["https://static.crates.io/crates/ripgrep/ripgrep-14.1.1.crate"],
    },
    "patches": [],
}

SAMPLE_NIX_ONLY = {
    "name": "iana-etc-20251215",
    "pname": "iana-etc",
    "version": "20251215",
    "storePath": "/nix/store/zzz12345678901234567890123456789-iana-etc-20251215",
}


# -- detect_upstream_ecosystem tests --


class TestDetectUpstreamEcosystem:
    def test_nix_native_pypi(self):
        dep = {"pname": "django", "version": "5.2.11", "ecosystem": "pypi"}
        result = detect_upstream_ecosystem(dep)
        assert result is not None
        assert result[:4] == ("pypi", "django", "5.2.11", 99)

    def test_nix_native_golang(self):
        dep = {"pname": "osv-scanner", "version": "2.3.3", "ecosystem": "golang"}
        result = detect_upstream_ecosystem(dep)
        assert result[:4] == ("golang", "osv-scanner", "2.3.3", 99)

    def test_nix_native_takes_precedence_over_url(self):
        dep = {**SAMPLE_PYPI_RICH, "ecosystem": "pypi"}
        result = detect_upstream_ecosystem(dep)
        assert result is not None
        assert result[3] == 99  # Nix-native confidence, not URL 95%

    def test_nix_native_null_falls_through(self):
        dep = {**SAMPLE_PYPI_RICH, "ecosystem": None}
        result = detect_upstream_ecosystem(dep)
        assert result is not None
        assert result[3] == 95  # Falls through to URL detection

    def test_pypi_via_nix_native(self):
        result = detect_upstream_ecosystem(SAMPLE_PYPI_RICH)
        assert result is not None
        eco_type, name, version, confidence, _reason = result
        assert eco_type == "pypi"
        assert name == "django"
        assert version == "5.2.11"
        assert confidence == 99  # Nix-native ecosystem field

    def test_pypi_via_src_url(self):
        result = detect_upstream_ecosystem(SAMPLE_PYPI_VIA_SRC_URL)
        assert result is not None
        eco_type, name, version, confidence, _reason = result
        assert eco_type == "pypi"
        assert name == "boto3"

    def test_pypi_via_wheel_filename(self):
        result = detect_upstream_ecosystem(SAMPLE_PYPI_WHEEL)
        assert result is not None
        eco_type, name, version, confidence, _reason = result
        assert eco_type == "pypi"
        assert name == "cryptography"

    def test_go_via_homepage(self):
        """Go package detected via URL heuristic (no ecosystem field)."""
        result = detect_upstream_ecosystem(SAMPLE_GO_PACKAGE)
        assert result is not None
        eco_type, name, version, confidence, _reason = result
        assert eco_type == "golang"
        assert name == "osv-scanner"
        assert confidence == 90  # URL-based fallback

    def test_cargo_via_nix_native(self):
        result = detect_upstream_ecosystem(SAMPLE_CARGO_PACKAGE)
        assert result is not None
        eco_type, name, version, confidence, _reason = result
        assert eco_type == "cargo"
        assert name == "ripgrep"
        assert confidence == 99  # Nix-native

    def test_no_signal_returns_none(self):
        result = detect_upstream_ecosystem(SAMPLE_NIX_ONLY)
        assert result is None

    def test_system_lib_with_cpe_no_ecosystem(self):
        """System lib with identifiers.cpe but no ecosystem URL → no ecosystem detected."""
        result = detect_upstream_ecosystem(SAMPLE_BUILDTIME[0])  # libunistring
        assert result is None

    def test_homepage_as_list(self):
        dep = {
            "pname": "foo",
            "version": "1.0",
            "meta": {"homepage": ["https://pypi.org/project/foo/", "https://github.com/foo"]},
        }
        result = detect_upstream_ecosystem(dep)
        assert result is not None
        assert result[0] == "pypi"



# -- Upstream PURL tests --


class TestUpstreamPurl:
    def test_ecosystem_package_gets_upstream_purl(self):
        comp, _ = build_component(SAMPLE_PYPI_RICH)
        assert str(comp.purl) == "pkg:pypi/django@5.2.11"

    def test_go_package_gets_upstream_purl(self):
        comp, _ = build_component(SAMPLE_GO_PACKAGE)
        assert str(comp.purl) == "pkg:golang/osv-scanner@2.3.3"

    def test_cargo_package_gets_upstream_purl(self):
        comp, _ = build_component(SAMPLE_CARGO_PACKAGE)
        assert str(comp.purl) == "pkg:cargo/ripgrep@14.1.1"

    def test_system_lib_keeps_nix_purl(self):
        comp, _ = build_component(SAMPLE_BUILDTIME[0])
        assert str(comp.purl) == "pkg:nix/libunistring@1.4.1"

    def test_no_ecosystem_keeps_nix_purl(self):
        comp, _ = build_component(SAMPLE_NIX_ONLY)
        assert str(comp.purl) == "pkg:nix/iana-etc@20251215"

    def test_system_lib_preserves_existing_cpe(self):
        comp, _ = build_component(SAMPLE_BUILDTIME[0])
        assert comp.cpe == "cpe:2.3:a:gnu:libunistring:1.4.1:*:*:*:*:*:*:*"

    def test_ecosystem_package_no_cpe(self):
        """Ecosystem packages without meta.identifiers have no CPE."""
        comp, _ = build_component(SAMPLE_PYPI_RICH)
        assert comp.cpe is None



# -- Nix properties tests --


class TestComponentType:
    def test_library_by_default(self):
        comp, _ = build_component(SAMPLE_PYPI_RICH)
        assert comp.type == ComponentType.LIBRARY

    def test_application_when_main_program(self):
        dep = {
            "pname": "osv-scanner", "version": "2.3.3",
            "storePath": "/nix/store/xxx-osv-scanner-2.3.3",
            "meta": {"mainProgram": "osv-scanner"},
        }
        comp, _ = build_component(dep)
        assert comp.type == ComponentType.APPLICATION

    def test_library_when_no_main_program(self):
        dep = {
            "pname": "boto3", "version": "1.40.55",
            "storePath": "/nix/store/xxx-boto3-1.40.55",
            "meta": {},
        }
        comp, _ = build_component(dep)
        assert comp.type == ComponentType.LIBRARY


class TestNixProperties:
    def test_store_path_property(self):
        comp, _ = build_component(SAMPLE_BUILDTIME[0])
        props = {p.name: p.value for p in comp.properties}
        assert props["nix:storePath"] == "/nix/store/1xakvg5jqmaiawwk0n1sbhvsvrdya512-libunistring-1.4.1"
        assert props["nix:packaged"] == "true"

    def test_maintainer_properties(self):
        comp, _ = build_component(SAMPLE_PYPI_RICH)
        props = {p.name: p.value for p in comp.properties}
        assert props["nix:maintainer:0:name"] == "Martin Weinelt"
        assert props["nix:maintainer:0:email"] == "hexa@darmstadt.ccc.de"
        assert props["nix:maintainer:0:github"] == "mweinelt"

    def test_no_maintainers_no_properties(self):
        comp, _ = build_component(SAMPLE_NIX_ONLY)
        props = {p.name for p in comp.properties}
        assert not any(p.startswith("nix:maintainer:") for p in props)


# -- Evidence tests --


class TestEvidence:
    def test_ecosystem_component_has_purl_evidence(self):
        comp, _ = build_component(SAMPLE_PYPI_RICH)
        assert comp.evidence is not None
        identities = list(comp.evidence.identity)
        assert len(identities) == 1
        ident = identities[0]
        assert str(ident.concluded_value) == "pkg:pypi/django@5.2.11"
        assert float(ident.confidence) == 0.99
        methods = list(ident.methods)
        assert len(methods) == 1
        assert methods[0].value == "nix ecosystem attribute"

    def test_url_detected_component_evidence(self):
        """Go package detected via URL has OTHER technique."""
        comp, _ = build_component(SAMPLE_GO_PACKAGE)
        assert comp.evidence is not None
        ident = list(comp.evidence.identity)[0]
        assert float(ident.confidence) == 0.90
        methods = list(ident.methods)
        assert "pkg.go.dev" in methods[0].value

    def test_unmapped_component_has_full_confidence(self):
        comp, _ = build_component(SAMPLE_NIX_ONLY)
        assert comp.evidence is not None
        ident = list(comp.evidence.identity)[0]
        assert str(ident.concluded_value) == "pkg:nix/iana-etc@20251215"
        assert float(ident.confidence) == 1.0



# -- Pedigree patches tests --


class TestPedigreePatches:
    def test_patches_emitted(self):
        comp, _ = build_component(SAMPLE_PYPI_RICH)
        assert comp.pedigree is not None
        patches = list(comp.pedigree.patches)
        assert len(patches) == 2
        assert patches[0].type == PatchClassification.UNOFFICIAL
        urls = [str(p.diff.url) for p in patches]
        assert "/nix/store/aaa-zoneinfo.patch" in urls
        assert "/nix/store/bbb-pythonpath.patch" in urls

    def test_no_patches_no_pedigree(self):
        comp, _ = build_component(SAMPLE_NIX_ONLY)
        assert comp.pedigree is None

    def test_empty_patches_no_pedigree(self):
        dep = {
            "pname": "foo", "version": "1.0",
            "storePath": "/nix/store/xxx-foo-1.0",
            "patches": [],
        }
        comp, _ = build_component(dep)
        assert comp.pedigree is None


# -- Known vulnerabilities tests --


class TestKnownVulnerabilities:
    def test_known_vulns_emitted(self):
        buildtime = [{
            "pname": "openssl", "version": "1.1.1",
            "path": "/nix/store/xxx12345678901234567890123456789-openssl-1.1.1",
            "meta": {"knownVulnerabilities": ["CVE-2024-1234", "CVE-2024-5678"]},
            "patches": [],
        }]
        runtime = ["/nix/store/xxx12345678901234567890123456789-openssl-1.1.1"]
        bom = build_bom(buildtime, runtime, "test")
        vulns = list(bom.vulnerabilities)
        assert len(vulns) == 2
        cve_ids = {v.id for v in vulns}
        assert "CVE-2024-1234" in cve_ids
        assert "CVE-2024-5678" in cve_ids

    def test_no_known_vulns_no_entries(self):
        bom = build_bom(SAMPLE_BUILDTIME, SAMPLE_RUNTIME, "test")
        assert len(bom.vulnerabilities) == 0


# -- Ecosystem component integration tests --


class TestBuildComponentEcosystem:
    def test_pypi_component_full(self):
        comp, eco = build_component(SAMPLE_PYPI_RICH)
        # Upstream PURL
        assert str(comp.purl) == "pkg:pypi/django@5.2.11"
        # No CPE (no meta.identifiers)
        assert comp.cpe is None
        # Pedigree has patches, not ancestors
        assert comp.pedigree is not None
        assert len(list(comp.pedigree.patches)) == 2
        # Ecosystem info returned
        assert eco is not None
        assert eco[0] == "pypi"

    def test_pypi_wheel_component(self):
        comp, _ = build_component(SAMPLE_PYPI_WHEEL)
        assert str(comp.purl) == "pkg:pypi/cryptography@46.0.5"

    def test_go_component(self):
        comp, _ = build_component(SAMPLE_GO_PACKAGE)
        assert str(comp.purl) == "pkg:golang/osv-scanner@2.3.3"

    def test_unmappable_component(self):
        comp, _ = build_component(SAMPLE_NIX_ONLY)
        assert str(comp.purl) == "pkg:nix/iana-etc@20251215"
        assert comp.cpe is None
        assert comp.pedigree is None


# -- Logging tests --


class TestEcosystemLogging:
    def test_mapping_summary_logged(self, caplog):
        import logging
        with caplog.at_level(logging.INFO, logger="nix-compliance-inator"):
            build_bom(
                SAMPLE_BUILDTIME,
                SAMPLE_RUNTIME,
                "test-closure",
            )
        summary_logs = [r for r in caplog.records if "ecosystem mapping summary" in r.message]
        assert len(summary_logs) == 1
        assert "unmapped:" in summary_logs[0].message

    def test_per_component_mapping_logged(self, caplog):
        import logging
        with caplog.at_level(logging.INFO, logger="nix-compliance-inator"):
            build_component(SAMPLE_PYPI_RICH)
        mapping_logs = [r for r in caplog.records if "upstream mapping:" in r.message]
        assert len(mapping_logs) == 1
        assert "pkg:pypi" in mapping_logs[0].message
        assert "confidence: 99%" in mapping_logs[0].message

    def test_unmapped_component_logged(self, caplog):
        import logging
        with caplog.at_level(logging.INFO, logger="nix-compliance-inator"):
            build_component(SAMPLE_NIX_ONLY)
        mapping_logs = [r for r in caplog.records if "upstream mapping:" in r.message]
        assert len(mapping_logs) == 1
        assert "pkg:nix/" in mapping_logs[0].message
