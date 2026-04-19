---
name: common-authoritative-sboms
description: Use when a change generates, converts, or re-derives SBOMs for a container image — e.g. "generate SBOMs with syft after the build", "scan the image to produce an SBOM", "re-scan the image for SBOM", "switch SBOM converter", "use syft convert", "produce a second SBOM with tool X", "reconcile the build SBOM and the scan SBOM", or editing `common/lib/scripts/build-and-push`, `common/lib/scripts/extract-sbom-attestation`, `common/lib/scripts/patch-sbom-root`, `common/lib/nix-compliance-inator/`, or proposing a new `nix build .#<image>.someOtherSbom` output. Also fires on proposing SBOM generation by scanning the finished image with `syft packages docker:...` or `grype packages` rather than reading the Nix-derived SBOM.
---

# Authoritative SBOMs

## The Principle

An image has **one authoritative SBOM**, derived from the build itself — typically extracted from the image's embedded build attestation layers. A post-hoc scan of the finished image is not a substitute: the build knows exactly which packages were installed, at which versions, from which ecosystem, with what file-level relationships. A scanner can only guess. When a different SBOM format is required, it is produced by **converting the authoritative SBOM using a converter that preserves relationships** — not by generating a second independent SBOM.

## When This Applies

- Proposing `syft packages docker:...` (or any scanner) as the canonical SBOM generation step.
- Adding a new SBOM format (CycloneDX alongside SPDX, or vice versa, or SWID).
- Switching the format converter (e.g. between converters that differ in relationship handling).
- Reconciling a mismatch between two SBOMs that describe the same image.
- Re-scanning released images "because the scanner got better".
- Generating an SBOM outside the unified build that flows into release artefacts.

## Rules

1. **The build is the source of truth.** For each image, there is exactly one authoritative SBOM, produced by the Nix derivation (e.g. `nix build .#<image>-image.patchedSbom`) in CycloneDX form, with full component-level relationships preserved by the nix-compliance-inator overlay (`common/lib/nix-compliance-inator/`).
2. **Format conversion is allowed; regeneration is not.** When a second format is needed, convert from the authoritative SBOM. Do not scan the image independently to produce it. In packages, the Nix build produces CycloneDX directly, so no format-conversion step exists. If a release ever requires SPDX, it must be derived from the Nix-produced CycloneDX, not from a fresh scan of the image.
3. **Use a converter that preserves relationships.** Any future SBOM-format conversion must round-trip the dependency graph. A converter that emits flat component lists is not acceptable for the authoritative conversion.
4. **Vulnerability scans run against the SBOM**, not against the image directly, so findings trace back to the same authoritative component list. Packages does this via `common/lib/scripts/scan-sbom`.
5. **All SBOMs in the release pack are consistent with each other** because they derive from the same root SBOM by conversion.
6. **Scanner-generated SBOMs are fine for local diagnostics** (comparing coverage, spot-checking components) — `sbomqs`, `sbomlyze`, and `cyclonedx-cli` are provided by the devShell for exactly this purpose. They must not be the source of truth that flows into the release.

## Common Violations

- **Using `syft` to produce the canonical SBOM by scanning the built image.** This creates a second, independent description of the image that will drift from the build's truth. In packages, the canonical SBOM is the `patchedSbom` output of the image's Nix derivation. Re-scanning the resulting OCI tarball with syft creates a second, drifting description.
- **Switching formats via a converter known to drop relationships.** The converted SBOM loses the dependency graph; vulnerability tooling then produces less useful output and supply-chain reasoning is weakened.
- **"Both SBOMs are in the release, pick whichever" semantics.** Releases contain one authoritative SBOM plus format conversions of it. Not two independently-produced SBOMs.
- **Re-scanning an already-released image to "refresh" its SBOM.** The image digest has not changed; the SBOM has not changed. Re-scanning invents differences. *Note:* re-running CVE scans (against the existing SBOM) is fine and is what `.github/workflows/rescan-vulnerabilities.yml` does — it scans the SBOM with a newer grype DB. Re-deriving the SBOM itself from the image is the violation.
- **Building an SBOM in the deploy workflow or release-promotion workflow.** SBOMs belong to the build; they flow through as artefacts.
- **Running the CVE scan against the image rather than against the SBOM.** Creates a second component universe and loses the traceability guarantee.

## Decision Heuristics

- If a proposed step starts with "scan the finished image to produce…", ask whether the build already produces it. The build almost always does — the Nix derivation has the package list before the image tarball is even assembled.
- If two SBOMs for one image disagree, the one produced by the build wins. Fix the other side.
- If the only reason to generate a second SBOM is "format X is expected downstream", that is a conversion task, not a generation task.
- If the converter drops edges, replace the converter — do not work around it by regenerating.
- Before adding a scanner to the pipeline, ask whether its output is intended to replace the build SBOM, or only to cross-check it. "Replace" is a violation; "cross-check" is fine as a diagnostic.

## Traceability Chain

```
nix build → patchedSbom (CycloneDX, authoritative) → CVE scan (grype against the SBOM)
                                                             ↓
                                                   findings trace back to
                                                   the authoritative
                                                   component list
```

If any arrow in that chain is broken by re-deriving (rather than reading the Nix-produced SBOM), downstream findings lose the guarantee that they describe the same image as was built.
