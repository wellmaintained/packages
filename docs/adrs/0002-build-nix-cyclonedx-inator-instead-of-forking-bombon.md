# 0002. Build nix-cyclonedx-inator instead of forking bombon

Date: 2026-03-21

## Status

accepted

## Context

The bombon project generates CycloneDX SBOMs for Nix packages, but the
maintainer declined an upstream PR (issue #177) that would have added the
features we need. We needed a way to generate CycloneDX SBOMs from Nix
derivations, and had several options for how to proceed.

Forking bombon was considered but rejected because it would mean inheriting
the existing codebase's constraints — particularly its Rust-based CycloneDX
generation which is stuck on CycloneDX 1.5 due to a crate bottleneck. A pure
Python replacement was also considered but would lose the Nix-native
derivation introspection that bombon does well.

## Decision

We will build nix-cyclonedx-inator as an independent project inspired by
bombon's approach, but not a fork. This gives us freedom to make different
architectural choices (particularly around SBOM generation tooling and
CycloneDX version support) without inheriting bombon's constraints or
maintaining compatibility with its codebase.

### Relation to other ADRs

See ADR 0003 for the choice of cyclonedx-python-lib as the SBOM generation
library, which is a direct consequence of not being tied to bombon's Rust
stack.

## Consequences

### Benefits

- Freedom to target CycloneDX 1.7 immediately without waiting for upstream
  Rust crate support.
- No obligation to maintain compatibility with bombon's API or conventions.
- Can make opinionated choices about overlay design (see ADR 0004) without
  upstream negotiation.

### Trade-offs

- No existing community or contributor base — starting from scratch.
- Cannot benefit from bombon bug fixes or improvements without manual porting.
- Must independently solve Nix derivation introspection problems that bombon
  has already solved.

### Future considerations

- If bombon eventually supports CycloneDX 1.7 and accepts the overlay
  approach, reconvergence could be considered.
- The name "nix-cyclonedx-inator" signals independence from bombon clearly.
