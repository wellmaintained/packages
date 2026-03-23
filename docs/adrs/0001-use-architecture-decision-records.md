# 0001. Use Architecture Decision Records

Date: 2026-03-21

## Status

accepted

## Context

The nix-cyclonedx-inator project is making architectural decisions that need
to be recorded for future reference. Multiple contributors — both human and
AI agents — make decisions that others need to understand later. Without a
structured record, the reasoning behind past choices is lost, leading to
repeated discussions, accidental reversals, or confusion about why the project
works the way it does.

## Decision

We will use Architecture Decision Records (ADRs) to document significant
architectural and design decisions. ADRs follow the Nygard template with
extensions:

- **Core sections**: Status, Context, Decision, Consequences
- **Extensions**: Relation to other ADRs subsection; Consequences split into
  Benefits, Trade-offs, and Future considerations
- **Naming**: 4-digit zero-padded numbers with kebab-case titles
  (e.g., `0001-use-architecture-decision-records.md`)
- **Location**: `docs/adr/` relative to the repository root
- **Index**: `docs/adr/README.md` with a markdown table linking all ADRs
- **Tooling**: use the `yak-adr` skill for creation and management

### Relation to other ADRs

This is the foundational ADR. All subsequent ADRs (0002-0005) follow the
conventions established here.

## Consequences

### Benefits

- Decisions are discoverable — new contributors can read the ADR index to
  understand past choices without archaeology.
- The structured format (Context/Decision/Consequences) forces clear
  articulation of trade-offs at decision time.
- Cross-references between ADRs make the decision graph navigable.
- AI agents can read ADRs to understand project constraints without
  re-deriving them from code.

### Trade-offs

- Writing ADRs adds overhead to the decision process — not every decision
  warrants one.
- ADRs can become stale if the codebase evolves but the records are not
  updated.
- The numbering scheme requires coordination when multiple contributors
  create ADRs concurrently.

### Future considerations

- If ADR volume grows significantly, consider adding tags or categories to
  the index for filtering.
- Revisit the template if sections consistently go unused or if additional
  sections are needed.
