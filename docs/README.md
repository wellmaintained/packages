# Architecture Decision Records

ADRs document significant architectural and design decisions.

## Index

| # | Decision | Status |
|---|----------|--------|
| [0001](adrs/0001-use-architecture-decision-records.md) | Use Architecture Decision Records | accepted |
| [0002](adrs/0002-build-compliant-image-and-rename-to-nix-compliance-inator.md) | buildCompliantImage and rename to nix-compliance-inator | proposed |
| [0003](adrs/0003-build-once-promote-on-merge.md) | Build once, promote on merge | accepted |
| [0004](adrs/0004-repo-structure-and-demo-narrative.md) | Repo structure and demo narrative | proposed |

## When to Write an ADR

Write an ADR when making decisions that:
- Change the architecture or core design patterns
- Introduce new dependencies or technologies
- Affect multiple components or the public API
- Have long-term maintenance implications
- Future maintainers will ask "why did we do it this way?"

Not for: minor implementation details, bug fixes, refactoring,
configuration changes.
