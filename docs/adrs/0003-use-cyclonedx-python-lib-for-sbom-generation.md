# 0003. Use cyclonedx-python-lib for SBOM generation

Date: 2026-03-21

## Status

accepted

## Context

bombon generates CycloneDX SBOMs using a Rust crate (cyclonedx-bom) that is
stuck on CycloneDX 1.5. The CycloneDX spec is now at 1.7, and we need to
target the latest version to stay current with the ecosystem. The Rust crate's
maintainers have not released 1.6 or 1.7 support, creating a bottleneck for
any Rust-based approach.

We considered three approaches for SBOM generation:
1. Wait for the Rust crate to catch up — unpredictable timeline.
2. Write our own CycloneDX serialization — significant effort, error-prone.
3. Use cyclonedx-python-lib — actively maintained, already supports 1.7.

## Decision

Use cyclonedx-python-lib as the SBOM generation library. The Nix derivation
introspection will extract dependency metadata, and a Python transformer will
use cyclonedx-python-lib to produce spec-compliant CycloneDX output.

This means nix-cyclonedx-inator has a Python component (the transformer)
alongside its Nix component (the overlay and derivation introspection).

### Relation to other ADRs

This decision follows from ADR 0002 (not forking bombon), which freed us
from the Rust stack. It enables ADR 0005 (targeting CycloneDX 1.7 only).

## Consequences

### Benefits

- Immediate access to CycloneDX 1.7 support without waiting for upstream
  Rust crate releases.
- cyclonedx-python-lib handles spec validation, serialization, and schema
  compliance — we don't need to implement these ourselves.
- Python is well-supported in Nix (nixpkgs has mature Python packaging).

### Trade-offs

- Introduces a Python dependency into what could otherwise be a pure-Nix
  project.
- Python runtime overhead compared to a compiled Rust solution (acceptable
  for a build-time tool).
- Must track cyclonedx-python-lib releases for new CycloneDX spec versions.

### Future considerations

- If a Nix-native CycloneDX library emerges, it could replace the Python
  dependency.
- The transformer's interface should be kept narrow so the SBOM generation
  backend can be swapped without changing the overlay.
