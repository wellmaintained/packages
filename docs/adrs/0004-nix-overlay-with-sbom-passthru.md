# 0004. Nix overlay with .sbom-cyclonedx-1-7 passthru

Date: 2026-03-21

## Status

accepted

## Context

We needed to decide how users access SBOMs for their Nix packages. The SBOM
should feel like a natural property of the package rather than an external
build step. Three approaches were considered:

1. **Standalone CLI** — a command-line tool that takes a derivation path and
   produces an SBOM. Simple but requires users to manage a separate build
   step and track which SBOM belongs to which package.

2. **Explicit wrapper only** — a function like `lib.withSbom pkg` that wraps
   a package and adds SBOM generation. Opt-in and explicit, but requires
   users to modify their package definitions.

3. **Overlay** — override `mkDerivation` globally so every package
   automatically gets an SBOM as a passthru attribute. Transparent but
   invasive.

## Decision

Use a Nix overlay that overrides `mkDerivation` to add a
`.sbom-cyclonedx-1-7` passthru attribute to every package. Also expose
`lib.withSbom` as an escape hatch for cases where the overlay approach
doesn't work (e.g., packages not built with `mkDerivation`).

The passthru attribute name includes the CycloneDX version to allow future
coexistence of multiple spec versions.

### Relation to other ADRs

This design is enabled by ADR 0002 (independence from bombon's approach).
The CycloneDX version in the attribute name reflects ADR 0005 (1.7 only,
initially).

## Consequences

### Benefits

- SBOMs are available for any package in the overlay without code changes —
  just access `pkg.sbom-cyclonedx-1-7`.
- The passthru approach means SBOMs are lazily evaluated — they're only built
  when accessed, so the overlay has zero cost for packages whose SBOMs are
  never requested.
- `lib.withSbom` provides an explicit alternative for edge cases.

### Trade-offs

- Overriding `mkDerivation` globally is invasive and may interact
  unexpectedly with other overlays that also override it.
- The versioned attribute name (`sbom-cyclonedx-1-7`) is less discoverable
  than a generic `sbom` attribute.
- Users must apply the overlay to their nixpkgs instance, which is an extra
  configuration step.

### Future considerations

- When CycloneDX 1.8 arrives, a new passthru attribute
  (`sbom-cyclonedx-1-8`) can coexist with the 1.7 one.
- If the overlay causes compatibility issues, `lib.withSbom` serves as a
  fallback that doesn't require the overlay at all.
- Consider providing a convenience function in the flake that applies the
  overlay to a given nixpkgs instance, reducing boilerplate for users who
  consume nix-cyclonedx-inator as a flake input.
