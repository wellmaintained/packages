---
name: common-sbom-enrichment
description: Use when a change enriches SBOMs with metadata (licenses, descriptions, suppliers, external references, lifecycle data), or touches the order of conversion vs. enrichment — e.g. "enrich the SBOMs", "improve SBOM quality", "fill in component metadata", "add license / supplier / description fields", "enrich before converting", "overwrite the raw SBOM with enriched data", "add an enrichment step", "backfill SBOM metadata", or editing `common/lib/scripts/enrich-sbom`, `common/pkgs/sbomify-action/`, the enrichment portion of `common/lib/scripts/build-and-push`, or the `Justfile` `build-image` recipe.
---

# Enrich After Conversion, Keep the Raw

## The Principle

Metadata enrichment (licences, descriptions, suppliers, external references, lifecycle data) runs **on the converted format**, after format conversion is complete, and is allowed to overwrite that converted file in place. The **raw build-time SBOM is never modified** — it stays on disk exactly as produced by the build, as the unmodified source of truth.

## When This Applies

- Adding or changing an enrichment step that adds component metadata from public registries.
- Deciding the order of conversion and enrichment in the compliance pipeline.
- Running enrichment on the raw SBOM format to "enrich everything earlier".
- Overwriting the raw build SBOM with an enriched version "since it's better now".
- Adding a new enrichment source or replacing the existing enrichment tool.
- Caching the enrichment output.

## Rules

1. **Two artefacts exist per image:** the raw SBOM as produced by the Nix derivation (`<name>.cdx.json` under `.local/build/sboms/` locally), and the enriched SBOM (`<name>.enriched.cdx.json`). Both ship; each serves a distinct purpose. Packages produces CycloneDX directly from the Nix build, so there is no separate format-conversion step — enrichment is the single post-build mutation, and only the enriched copy is mutated.
2. **Enrichment runs on the build-produced CycloneDX file** (`<name>.cdx.json`), writing to a separate enriched file (`<name>.enriched.cdx.json`). Where DHI's pipeline enriches in place after a SPDX→CycloneDX conversion, packages keeps the raw and enriched as two distinct files side-by-side.
3. **The raw SBOM is immutable.** In packages, the raw SBOM is the `.cdx.json` file produced by `nix build .#<image>-image.patchedSbom`. It is never overwritten by the enrichment step. The enriched copy is a sibling file.
4. **Enrichment is best-effort.** Components that cannot be looked up in public registries remain as they were — enrichment does not fail the build for private or vendored packages.
5. **Enrichment is additive.** It does not remove or invalidate existing fields; it fills gaps.
6. **The enrichment output is cacheable**, keyed on (raw SBOM content + tool versions). Identical inputs must produce identical enriched output.

## Common Violations

- **Running enrichment on the raw SBOM before conversion.** In packages there is no conversion step (Nix produces CycloneDX directly), so this specific failure mode does not apply. The remaining hazard — overwriting the raw SBOM with the enriched version — applies fully.
- **Converting the enriched SBOM into additional formats.** That makes the converter responsible for preserving enrichment metadata it was not designed for. Do the enrichment **per target format**, on the converted file.
- **Overwriting `<name>.cdx.json` with the enriched output** (rather than writing to `<name>.enriched.cdx.json`). Breaks the guarantee that the raw is the unmodified Nix-build output.
- **Publishing only the enriched SBOM.** Consumers who want to verify provenance need the raw one too. Ship both.
- **An enrichment step that fails the build when a component cannot be enriched.** Enrichment is best-effort; missing metadata is an expected state. (`common/lib/scripts/enrich-sbom` already implements this — it skips enrichment gracefully if `SBOMIFY_TOKEN` is unset.)
- **A cache keyed on the output file path rather than on input content + tool versions.** Produces stale enrichment after an underlying data source updates.
- **Enrichment running as a post-release step.** Enrichment belongs in the unified build, so the enriched SBOM is what flows through the release pipeline.

## Decision Heuristics

- Order in packages: **nix build (raw `.cdx.json`) → enrich (`.enriched.cdx.json`) → scan**. There is no conversion step; the build emits CycloneDX directly. Anything that mutates the raw `.cdx.json` after the build is probably a violation; look closely.
- If an enrichment-added field disappears between two pipeline stages, check whether enrichment ran before a (hypothetical future) conversion.
- If someone proposes "let's just enrich the raw SBOM in place — it's richer", explain that the raw is the preserved source of truth. Enrich the sibling `.enriched.cdx.json` instead.
- If you are writing code that mutates the raw SBOM after it was built by Nix, stop.
- If a new enrichment tool only operates on a different format, treat that as a mismatch to solve — either add a conversion step (preserving the raw) or pick a tool that handles CycloneDX.

## Why "keep the raw"

The raw build SBOM is the one artefact in the release that is provably a direct product of the Nix derivation. Everything downstream of it — enrichment, scan, future conversion — is interpretation layered on top. Preserving the raw means that if any layer above it is later found to be wrong, the ground truth is still present, immutable, and independently verifiable. Enrichment is valuable; it is also optional in a way that the raw SBOM is not.
