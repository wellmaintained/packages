---
name: common-unified-compliance-output
description: Use when a change adds, moves, or splits a compliance step that produces artefacts for a container image — e.g. "add a Trivy scan step", "scan the image with syft", "add a new build step that runs X on the image", "add a separate SBOM command", "add a separate enrich target", "add a post-build signing step in CI", or editing `common/lib/scripts/build-and-push`, `common/lib/scripts/scan-sbom`, `common/lib/scripts/enrich-sbom`, `common/lib/scripts/extract-sbom-attestation`, `common/lib/scripts/patch-sbom-root`, `common/lib/nix-compliance-inator/`, `Justfile` (the `build-image` recipe), or `.github/workflows/build.yml`. Also fires on proposing a scan or SBOM generation outside the unified `just build-image` / `build-and-push` path.
---

# One Command, All Compliance Outputs

## The Principle

Building a container image and producing its compliance artefacts — SBOMs (all formats), vulnerability scan, secrets scan, provenance attestation, VEX — is **one operation**. A single command produces a complete, consistent output set for that image. There are no separate `scan`, `sbom`, or `attest` top-level targets. Callers never have to know a correct sequence of sub-commands to get a "valid" release.

## When This Applies

- Adding a new kind of scan or attestation (license scan, policy scan, signed SBOM format, etc.).
- Proposing a new `just` target, Make target, or script that produces one compliance artefact for an already-built image.
- Moving an existing step out of the unified build to "run it separately" for speed or convenience.
- Adding a CI step that scans or re-analyses the image after the build has finished.
- Removing a step from the unified build because it "isn't needed every time".

## Rules

1. **The image and all its compliance artefacts are produced by one entry point.** Calling that entry point exactly once, for a single image, is the complete compliance build.
2. **Everything lands in one predictable location**, typically `.local/build/sboms/<name>.cdx.json` (locally) and the build matrix's uploaded artifact (in CI). After the command completes, every artefact a downstream consumer needs is present.
3. **No partial success.** If a step fails, the build fails. There is no "it built but the SBOM didn't generate" state that ships.
4. **New compliance capabilities extend the unified build.** A new scan becomes another step inside the unified path, writing to the same output location, with the same failure semantics.
5. **CI orchestrates; it does not replace.** CI calls the unified build per image. It does not inline the individual steps or substitute its own sequence.
6. **Local and CI produce the same artefact set.** A developer who runs the unified build locally gets the same outputs CI produces.

## Common Violations

- **A new top-level `just scan-foo` (or equivalent recipe) that operates on an already-built image.** The new scan belongs inside `common/lib/scripts/build-and-push` (or a function it calls), not as a sibling Justfile recipe that callers have to remember to run.
- **CI workflow that calls `just build`, then `just scan`, then `just sbom-xyz`.** That sequence means someone can forget a step and the release still ships. Collapse it into one call.
- **A scan marked "optional" or gated by a workflow-level flag.** Either it's part of the compliance contract (unified build) or it isn't in the pipeline at all.
- **A nightly or out-of-band workflow that "re-scans" released images.** This indicates the unified build is missing a step — add it there instead so every future release includes it.
- **"Just run it manually once" documentation.** If it's part of the release, it's part of the unified build; if it's truly one-off, it's not a release artefact.
- **Splitting by artefact type ("SBOM pipeline" vs "scan pipeline").** Split the code into functions/scripts if needed, but keep the **invocation** unified per image.
- **Asking the caller to assemble outputs from several directories.** One image → one output location.

## Decision Heuristics

- If you are writing a new script that reads `.local/build/sboms/<name>.cdx.json` and writes a new file, that script is a step of the unified build — call it from there.
- If a CI job depends on `<name>.<new-thing>.json`, the unified build must already produce `<new-thing>.json`. CI never produces it itself.
- If the answer to "how do I get compliance output X for image Y?" is anything other than "run the unified build for Y", there is a violation.
- If you feel tempted to expose a sub-step as a separate target "for speed while iterating", that is what cached intermediate outputs and internal functions inside the unified build are for — not a new public target.
- Before adding a scan, ask: "If this scan fails, should the release be blocked?" If yes, it belongs in the unified build. If no, it does not belong in the release pipeline at all.

## Invariants for the Output

After a successful unified build for image `X`, the predictable output location for `X` (locally `.local/build/sboms/X.cdx.json` and the matching CI upload) must contain every artefact the release contract promises for `X`. Downstream jobs (compliance pack assembly, signing, attestation upload) must be able to rely on that shape without extra conditional logic for "if this particular scan was run this particular time".

The output is the contract. If it exists and the build exited zero, the release for that image is complete.
