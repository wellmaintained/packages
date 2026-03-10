# SBOM Tooling Evaluation: bombon vs sbomnix

Evaluated 2026-03-10. Both tools generate SBOMs for Nix-built packages; we tested them against our caddy and postgres OCI images.

## Tools Under Test

| | bombon | sbomnix |
|---|---|---|
| Repo | [nikstur/bombon](https://github.com/nikstur/bombon) | [tiiuae/sbomnix](https://github.com/tiiuae/sbomnix) |
| Language | Rust (Nix library) | Python (CLI) |
| Interface | Nix function (`buildBom`) | CLI (`sbomnix <path-or-flakeref>`) |
| In nixpkgs | No (separate flake) | Yes (currently broken due to dependency) |
| Output formats | CycloneDX JSON only | CycloneDX JSON, SPDX JSON, CSV |

## Head-to-Head Comparison

### Caddy 2.11.2

| Metric | bombon | sbomnix (store path) | sbomnix (flakeref) |
|---|---|---|---|
| CycloneDX spec version | 1.5 | 1.4 | 1.4 |
| Component count | 8 | 7 | 7 |
| Components with licenses | 6 (75%) | 0 (0%) | 6 (86%) |
| Components with descriptions | 6 (75%) | 0 (0%) | 6 (86%) |
| Components with PURL | 8 (100%) | 7 (100%) | 7 (100%) |
| Components with externalReferences | 6 (75%) | 0 (0%) | 0 (0%) |
| Components with CPE | 0 | 7 (100%) | 7 (100%) |

### PostgreSQL 17.9

| Metric | bombon | sbomnix (store path) | sbomnix (flakeref) |
|---|---|---|---|
| CycloneDX spec version | 1.5 | 1.4 | 1.4 |
| Component count | 24 | 63 | 63 |
| Components with licenses | 23 (96%) | 0 (0%) | 56 (89%) |
| Components with descriptions | 24 (100%) | 0 (0%) | 58 (92%) |
| Components with PURL | 24 (100%) | 62 (98%) | 62 (98%) |
| Components with externalReferences | 24 (100%) | 0 (0%) | 0 (0%) |
| Components with CPE | 0 | 63 (100%) | 63 (100%) |

## Key Observations

### Component count difference

sbomnix reports significantly more components for postgres (63 vs 24). This is because sbomnix walks the full Nix runtime closure -- including transitive dependencies like `acl`, `attr`, `bash`, `bison`, `coreutils`, `flex`, `gcc`, and many other build/runtime support libraries. bombon reports a more curated set that represents the direct and meaningful transitive runtime dependencies.

Neither count is wrong -- they reflect different philosophies. sbomnix gives a more exhaustive (potentially noisy) view; bombon gives a more focused view of what actually matters for vulnerability assessment.

### License accuracy

- **bombon**: Uses proper SPDX license identifiers from nixpkgs meta (e.g., `LGPL-3.0-or-later`, `PostgreSQL`, `Apache-2.0`). 96% coverage on postgres.
- **sbomnix (flakeref)**: Also uses SPDX identifiers from nixpkgs meta when given a flakeref. 89% coverage on postgres.
- **sbomnix (store path)**: Zero license data when given a bare store path -- it cannot resolve nixpkgs metadata without the flake context.

### Metadata richness

bombon includes `externalReferences` with source URLs and SHA-256 hashes, plus `description` fields. This is valuable for supply chain verification. sbomnix includes `CPE` identifiers (useful for vulnerability matching) and `nix:drv_path`/`nix:output_path` properties (useful for Nix-specific tooling).

### CycloneDX spec version

bombon generates CycloneDX 1.5 (current); sbomnix generates 1.4 (one version behind). CycloneDX 1.5 adds support for additional component evidence, formulation, and improved vulnerability tracking.

### Integration model

- **bombon** is a Nix library. You call `buildBom` in your flake.nix and the SBOM is a Nix derivation -- it gets built alongside your image, is cacheable, and is reproducible. This fits naturally into a Nix-native workflow.
- **sbomnix** is a CLI tool. You run it after building, pointing at a store path or flakeref. This is more flexible for ad-hoc use but requires a separate step in CI and doesn't benefit from Nix caching.

### Availability

- bombon requires adding it as a flake input (`github:nikstur/bombon`). Not in nixpkgs.
- sbomnix is in nixpkgs but currently broken (dependency `requests-ratelimiter` marked as broken). Works when run from the upstream flake (`github:tiiuae/sbomnix`).

## Decision

**Use bombon** for SBOM generation in this project.

Rationale:

1. **Nix-native integration**: bombon's `buildBom` function fits naturally into our flake.nix. SBOMs become derivations alongside our OCI images -- built, cached, and versioned together.

2. **Richer metadata out of the box**: Source URLs with SHA-256 hashes and descriptions are included without needing a flakeref. This matters because our CI pipeline builds from store paths.

3. **CycloneDX 1.5 compliance**: Meets BSI TR-03183 and US EO 14028 requirements. sbomnix generates the older 1.4 spec.

4. **Focused component list**: bombon's curated dependency list is more useful for vulnerability assessment than sbomnix's exhaustive closure walk. Including `bison` and `flex` in a postgres SBOM adds noise without security value.

5. **Reproducible by construction**: As a Nix derivation, the SBOM is bit-for-bit reproducible. sbomnix's output includes random UUIDs and timestamps.

### When to also consider sbomnix

sbomnix is worth keeping in mind for:
- Ad-hoc vulnerability scanning (its `vulnxscan` companion tool)
- Build-time dependency auditing (`--buildtime` flag)
- SPDX output (bombon only does CycloneDX)
- CPE-based vulnerability matching (bombon doesn't emit CPEs)

### Next steps

1. Add `bombon` as a flake input to `flake.nix`
2. Create SBOM derivations for each OCI image using `buildBom` with `extraPaths`
3. Include SBOMs in CI artifacts alongside the images
