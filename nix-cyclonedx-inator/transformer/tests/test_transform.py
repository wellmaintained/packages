"""Tests for the Nix-to-CycloneDX transformer."""

import json
import os
import tempfile

import pytest

import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from transform import (
    build_bom,
    build_component,
    extract_external_references,
    extract_licenses,
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
        },
        "src": {
            "urls": [
                "https://ftpmirror.gnu.org/libunistring/libunistring-1.4.1.tar.gz"
            ],
            "hash": "12542ad7619470efd95a623174dcd4b364f2483caf708c6bee837cb53a54cb9d",
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

    def test_no_refs(self):
        dep = {"src": {}, "meta": {}}
        refs = extract_external_references(dep)
        assert len(refs) == 0


# -- build_component tests --


class TestBuildComponent:
    def test_full_component(self):
        dep = SAMPLE_BUILDTIME[0]
        comp = build_component(dep)
        assert comp.name == "libunistring"
        assert comp.version == "1.4.1"
        assert str(comp.purl) == "pkg:nix/libunistring@1.4.1"
        assert comp.description == "Unicode string library"
        assert len(comp.licenses) == 1
        assert len(comp.external_references) == 2  # source + homepage

    def test_minimal_component(self):
        dep = {"name": "simple", "version": "1.0", "storePath": "/nix/store/aaa-simple-1.0"}
        comp = build_component(dep)
        assert comp.name == "simple"
        assert comp.version == "1.0"
        assert len(comp.licenses) == 0
        assert len(comp.external_references) == 0


# -- build_bom tests --


class TestBuildBom:
    def test_produces_valid_bom(self):
        bom = build_bom(SAMPLE_BUILDTIME, SAMPLE_RUNTIME, "test-closure")
        assert bom.metadata.component.name == "test-closure"
        assert len(bom.components) > 0
        # Tool metadata
        tool_names = {t.name for t in bom.metadata.tools.components}
        assert "nix-cyclonedx-inator" in tool_names

    def test_spec_version_is_1_7(self):
        bom = build_bom(SAMPLE_BUILDTIME, SAMPLE_RUNTIME, "test-closure")
        from cyclonedx.output.json import JsonV1Dot7

        outputter = JsonV1Dot7(bom)
        output = json.loads(outputter.output_as_string())
        assert output["specVersion"] == "1.7"
        assert output["bomFormat"] == "CycloneDX"

    def test_dependency_graph(self):
        bom = build_bom(SAMPLE_BUILDTIME, SAMPLE_RUNTIME, "test-closure")
        from cyclonedx.output.json import JsonV1Dot7

        outputter = JsonV1Dot7(bom)
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

    def test_components_have_required_fields(self):
        bom = build_bom(SAMPLE_BUILDTIME, SAMPLE_RUNTIME, "test-closure")
        from cyclonedx.output.json import JsonV1Dot7

        outputter = JsonV1Dot7(bom)
        output = json.loads(outputter.output_as_string())

        for comp in output["components"]:
            assert "name" in comp
            assert "version" in comp
            assert "type" in comp
            assert "purl" in comp
            assert "scope" in comp
            assert comp["type"] == "application"
            assert comp["scope"] == "required"
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

            assert output["specVersion"] == "1.7"
            assert output["bomFormat"] == "CycloneDX"
            assert output["metadata"]["component"]["name"] == "test-app-closure"
            assert len(output["components"]) == 3  # libunistring, bash, unknown-runtime

            # Verify the rich component has all fields
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
            assert output["specVersion"] == "1.7"
            assert output.get("components", []) == []
        finally:
            os.unlink(bt_path)
            os.unlink(rt_path)
