# 0005. CycloneDX 1.7 only (initially)

Date: 2026-03-21

## Status

superseded by ADR 0006 — Downgrade CycloneDX Output from 1.7 to 1.6

## Context

The CycloneDX specification has multiple active versions (1.4, 1.5, 1.6,
1.7). Supporting multiple versions simultaneously adds complexity to the
codebase: different schema validations, different serialization paths, and
version-specific features that may or may not apply.

bombon is stuck on CycloneDX 1.5 due to its Rust crate dependency. One
motivation for building nix-cyclonedx-inator (see ADR 0002) was to target
the latest spec version without that constraint.

## Decision

Target CycloneDX 1.7 only for the initial release. Do not implement support
for older spec versions (1.4, 1.5, 1.6) until there is concrete demand from
users.

### Relation to other ADRs

This is enabled by ADR 0003 (cyclonedx-python-lib supports 1.7). The
versioned passthru attribute name in ADR 0004 (`sbom-cyclonedx-1-7`) is
designed to accommodate future versions when they're added.

## Consequences

### Benefits

- Simpler codebase — one serialization path, one schema, one set of tests.
- Can use CycloneDX 1.7 features (improved vulnerability tracking, expanded
  licensing model) without compatibility constraints.
- Faster time to a working tool — no multi-version matrix to validate.

### Trade-offs

- Users whose tooling only accepts older CycloneDX versions cannot use
  nix-cyclonedx-inator until we add support or they upgrade.
- Some SBOM consumers in regulated industries may require specific older
  versions for compliance.
- No support for SPDX, the other major SBOM standard. Users in ecosystems
  that mandate SPDX (e.g., some Linux Foundation projects) cannot use
  nix-cyclonedx-inator without a separate CycloneDX-to-SPDX conversion step.

### Future considerations

- Add older version support when a concrete user need arises — not
  speculatively.
- The versioned passthru attribute name (ADR 0004) means adding 1.6 support
  would produce `sbom-cyclonedx-1-6` alongside `sbom-cyclonedx-1-7`,
  avoiding breaking changes.
- cyclonedx-python-lib supports multiple spec versions, so the generation
  side is already capable — the work would be in testing and validation.
