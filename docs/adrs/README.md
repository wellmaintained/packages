# Architecture Decision Records

ADRs document significant architectural and design decisions.

## Index

| # | Decision | Status |
|---|----------|--------|
| [0001](0001-use-architecture-decision-records.md) | Use Architecture Decision Records | accepted |
| [0002](0002-build-nix-cyclonedx-inator-instead-of-forking-bombon.md) | Build nix-cyclonedx-inator instead of forking bombon | accepted |
| [0003](0003-use-cyclonedx-python-lib-for-sbom-generation.md) | Use cyclonedx-python-lib for SBOM generation | accepted |
| [0004](0004-nix-overlay-with-sbom-passthru.md) | Nix overlay with .sbom-cyclonedx-1-7 passthru | accepted |
| [0005](0005-cyclonedx-1-7-only-initially.md) | CycloneDX 1.7 only (initially) | superseded |
| [0006](0006-downgrade-cyclonedx-output-from-1-7-to-1-6.md) | Downgrade CycloneDX Output from 1.7 to 1.6 | accepted |

## When to Write an ADR

Write an ADR when making decisions that:
- Change the architecture or core design patterns
- Introduce new dependencies or technologies
- Affect multiple components or the public API
- Have long-term maintenance implications
- Future maintainers will ask "why did we do it this way?"

Not for: minor implementation details, bug fixes, refactoring,
configuration changes.
