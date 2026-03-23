# 0002. buildCompliantImage and rename to nix-compliance-inator

Date: 2026-03-22

## Status

proposed

## Context

PR #12 introduced nix-cyclonedx-inator, which generates CycloneDX SBOMs for
Nix-built docker images. The integration works but has two UX problems:

**1. Image and SBOM declarations are decoupled.** Each image spec
(e.g. `images/redis.nix`) returns `{ image; sbom; }` where `sbom.closure`
manually re-lists the same packages as `image.contents`. This duplication
can drift silently — add a package to the image, forget the SBOM, ship an
incomplete SBOM with no error.

**2. The wiring in flake.nix has 3 layers of indirection.** Each image
requires entries in `sbomOnlyTargets` (pluck closure), `sbomOnlyWrapped`
(batch-wrap with `withSbomAll`), and `packages` (attach metadata via
`overrideAttrs`). Adding a new image means editing 4 places.

More fundamentally, the tool's scope is broader than CycloneDX SBOMs.
An SBOM is one compliance artifact among several — OCI image annotations,
vulnerability exchange (VEX), provenance, and signing are all part of
shipping compliant container images. The tool should be designed around
compliance, not around a single SBOM format.

Two compliance standards inform the design:

- **NTIA Minimum Elements for SBOM (2021)** — 7 required data fields:
  component name, version, supplier name, unique identifier, dependency
  relationship, SBOM author, and timestamp. Our current tooling satisfies
  all of these.

- **BSI TR-03183-2 v2.1.0** — extends NTIA with mandatory license (SPDX),
  cryptographic hash, filename, dependency completeness, and file-level
  classification properties (executable, archive, structured). We satisfy
  the top-level fields but not yet the file-level properties.

## Decision

### 1. Rename nix-cyclonedx-inator to nix-compliance-inator

The tool's purpose is compliance, not CycloneDX specifically. The new name
reflects that SBOM generation (in any format) is one capability among
several compliance concerns.

### 2. Introduce `buildCompliantImage` as the primary API

A single function in the overlay that takes an image definition with
compliance metadata and returns the image plus all compliance artifacts.
The SBOM is derived from the image contents — there is no separate
declaration, so drift is structurally impossible.

#### Input

```nix
redis = pkgs.buildCompliantImage {
  # Identity — flows into OCI labels, SBOM metadata, and compliance artifacts
  name = "redis";
  version = pkgs.redis.version;
  license = pkgs.redis.meta.license.spdxId;
  description = "Redis server — Nix-built minimal OCI image";
  tag = "dev";

  # Roles
  creator = {                          # who made the software
    name = "Redis Ltd";
    url = "https://redis.io";
  };
  packager = {                         # who packaged this image & generated compliance data
    name = "wellmaintained";
    email = "sbom@wellmaintained.io";
    url = "https://wellmaintained.io";
  };

  # Image contents
  packages = [ pkgs.redis ];          # go in image AND SBOM
  # extraContents = [];               # go in image only (scripts, configs)

  imageConfig = {
    Entrypoint = [ "${pkgs.redis}/bin/redis-server" ];
    ExposedPorts = { "6379/tcp" = {}; };
    Env = [ "REDIS_DATA=/data" ];
  };

  # Unstructured pass-through for deployment-specific data
  extraMetadata = {
    sbomifyComponentId = "ABBCcw2YiYrG";
  };
};
```

No vendor default, no hardcoded source URL — the tool makes no assumptions
about who is using it.

#### Attribute mapping

Top-level attributes are named after compliance concepts and map to both
OCI labels and SBOM fields:

| Attribute | OCI Label | CycloneDX | SPDX | NTIA | BSI |
|-----------|-----------|-----------|------|------|-----|
| `name` | `image.title` | component name | PackageName | required | required |
| `version` | `image.version` | component version | PackageVersion | required | required |
| `license` | `image.licenses` | component license | PackageLicense | recommended | required |
| `description` | `image.description` | — | PackageComment | — | — |
| `creator` | — | `component.manufacturer` | PackageOriginator | — | required |
| `packager` | `image.vendor` | `metadata.authors` + `metadata.supplier` | Creator | required | required |
| `sourceUrl` | `image.source` | — | — | — | — |
| *purl* | — | component purl | ExternalRef/purl | required | recommended |
| *hash* | — | component hash | PackageChecksum | recommended | required |
| *timestamp* | — | metadata.timestamp | Created | required | required |
| *dependencies* | — | dependency graph | Relationship | required | required |

*Italic* fields are auto-derived (not user-supplied). `purl` is
auto-generated from name and version but can be overridden.

#### Output: `{ image; metadata; compliance; }`

```nix
# The OCI image
redis.image

# Metadata — actual artifacts and data
redis.metadata.name                          # "redis"
redis.metadata.version                       # "7.4.2"
redis.metadata.license                       # "BSD-3-Clause"
redis.metadata.creator                       # { name = "Redis Ltd"; ... }
redis.metadata.packager                      # { name = "wellmaintained"; ... }
redis.metadata.sbom.cyclonedx-1-6            # CycloneDX 1.6 JSON derivation
redis.metadata.labels                        # OCI annotation attrset
redis.metadata.extra.sbomifyComponentId      # pass-through data

# Compliance — views into metadata (links, not new derivations)
redis.compliance.ntia-minimum-elements.sbom  # -> metadata.sbom.cyclonedx-1-6
redis.compliance.bsi-tr-03183-2.sbom         # -> metadata.sbom.cyclonedx-1-6
redis.compliance.oci-image-spec.labels       # -> metadata.labels
```

The `compliance` tree contains only links into the `metadata` tree. Adding
a new standard means adding a new attrset of links — no new derivations,
no changes to existing consumers. When a standard requires an artifact we
don't yet generate (e.g. OpenVEX for BSI), we add it to `metadata` first,
then link it from `compliance`.

#### flake.nix simplification

The 3-layer wiring collapses:

```nix
# Before: 4 touch points per image
sbomOnlyTargets.redis = redis.sbom.closure;
sbomOnlyWrapped = pkgs.withSbomAll sbomOnlyTargets ...;
packages.redis-sbom = sbomOnlyWrapped.redis.sbom-cyclonedx-1-6.overrideAttrs { ... };

# After: 2 lines per image
packages.redis-image = redis.image;
packages.redis-sbom = redis.metadata.sbom.cyclonedx-1-6;
```

### 3. Keep `buildSbom`, `withSbom`, `withSbomAll` as lower-level API

`buildCompliantImage` is the high-level API for the common case (docker
images). The existing functions remain available for users who need SBOM
generation for non-image derivations.

### Relation to other ADRs

None. This ADR supersedes the earlier incremental decisions (originally
ADRs 0002-0006) that were removed during consolidation. Key design choices
carried forward: independence from bombon, use of cyclonedx-python-lib for
SBOM generation, the Nix overlay pattern with `withSbom`/`withSbomAll`
(now relegated to lower-level API), and CycloneDX 1.6 as the initial
output format.

## Consequences

### Benefits

- **Drift is structurally impossible.** The SBOM is derived from
  `packages` — the same list that populates `image.contents`. There is no
  separate declaration to forget.
- **Metadata is declared once.** `name`, `version`, `license`, `creator`,
  and `packager` flow into OCI labels, SBOM fields, and compliance
  artifacts from a single declaration.
- **Adding a new image is 1 file + 2 lines.** Create the image spec,
  add `<name>-image` and `<name>-sbom` to flake.nix packages. No
  intermediate wiring.
- **Standards are extensible without changing consumers.** New compliance
  standards add links in the `compliance` tree. New artifact types add
  entries in the `metadata` tree. Existing code is untouched.
- **The tool is reusable.** No hardcoded vendor, source URL, or
  repo-specific assumptions. Any Nix project can use
  nix-compliance-inator.

### Trade-offs

- **`buildCompliantImage` couples SBOM generation to docker image
  building.** This is intentional — SBOMs are compliance artifacts that
  ship with release artifacts. Users who need SBOMs for non-image
  derivations use the lower-level `buildSbom` / `withSbom` API.
- **Rename has a migration cost.** All references to
  nix-cyclonedx-inator (flake inputs, directory names, documentation)
  must be updated. This is a one-time cost.
- **BSI TR-03183-2 compliance is not yet complete.** File-level
  properties (executable, archive, structured) require transformer
  enhancements. The `compliance.bsi-tr-03183-2` entry will initially
  link to the same artifacts as `compliance.ntia-minimum-elements`,
  with BSI-specific gaps documented.

### Future considerations

- **BSI file-level properties.** The transformer needs to inspect closure
  contents and classify files as executable/archive/structured. This is a
  targeted enhancement to the Python transformer, not an API change.
- **OpenVEX / CSAF.** When vulnerability exchange is needed, add
  `metadata.vex.openvex` and link from
  `compliance.bsi-tr-03183-2.vex`.
- **SPDX output.** Add `metadata.sbom.spdx-2-3` when there is concrete
  demand. The compliance tree lets different standards link to different
  formats.
- **SLSA provenance.** Add `metadata.provenance.slsa-v1` for supply
  chain integrity attestations.
- **Signing.** CycloneDX supports signed SBOMs. Could be exposed as
  `metadata.sbom.cyclonedx-1-6-signed`.
