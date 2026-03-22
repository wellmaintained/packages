# Architecture Decision Records

ADRs document significant architectural and design decisions.

## Index

| # | Decision | Status |
|---|----------|--------|
| [0001](adrs/0001-use-architecture-decision-records.md) | Use Architecture Decision Records | accepted |
| [0002](adrs/0002-build-nix-cyclonedx-inator-instead-of-forking-bombon.md) | Build nix-cyclonedx-inator instead of forking bombon | accepted |
| [0003](adrs/0003-use-cyclonedx-python-lib-for-sbom-generation.md) | Use cyclonedx-python-lib for SBOM generation | accepted |
| [0004](adrs/0004-nix-overlay-with-sbom-passthru.md) | Nix overlay with .sbom-cyclonedx-1-7 passthru | superseded |
| [0005](adrs/0005-cyclonedx-1-7-only-initially.md) | CycloneDX 1.7 only (initially) | superseded |
| [0006](adrs/0006-downgrade-cyclonedx-output-from-1-7-to-1-6.md) | Downgrade CycloneDX Output from 1.7 to 1.6 | accepted |
| [0007](adrs/0007-build-compliant-image-and-rename-to-nix-compliance-inator.md) | buildCompliantImage and rename to nix-compliance-inator | proposed |

## When to Write an ADR

Write an ADR when making decisions that:
- Change the architecture or core design patterns
- Introduce new dependencies or technologies
- Affect multiple components or the public API
- Have long-term maintenance implications
- Future maintainers will ask "why did we do it this way?"

Not for: minor implementation details, bug fixes, refactoring,
configuration changes.
