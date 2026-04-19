---
name: nix-sbom-enrichment
description: Use when a change touches how SBOMs are enriched in this repo — e.g. "enrich the CycloneDX SBOM", "bump the sbomify-action version", "replace sbomify-action with another enrichment tool", "swap the enrichment step", "enrichment is failing", "make enrichment run in CI", "add the enrichment step to <script>", editing `common/lib/scripts/enrich-sbom`, `common/pkgs/sbomify-action/`, the `enrich` step of `common/lib/scripts/build-and-push`, or the `sbomify-action-src` flake input in `flake.nix`.
---

# Nix-based SBOM Enrichment Mechanism

## The Mechanism

SBOM enrichment in this repo is performed by the `sbomify-action` CLI, packaged as a Nix derivation under `common/pkgs/sbomify-action/` (sourced from the `sbomify-action-src` flake input pinned in `flake.nix`) and exposed on the dev/CI shell PATH via the `default` and `ci` devShells. The actual enrichment call is wrapped by `common/lib/scripts/enrich-sbom`:

```
sbomify-action --component-id <id> --component-name <name> --component-version <ver> \
               --augment --enrich --no-upload --output-file <output> <input>
```

The wrapper:

- Reads `SBOMIFY_TOKEN` from the environment. If unset, enrichment is **skipped gracefully** (the input file is copied to the output path); the caller does not fail.
- Operates on the Nix-produced CycloneDX SBOM (`.local/build/sboms/<name>.cdx.json`) and writes a new file (`.local/build/sboms/<name>.enriched.cdx.json`). The raw `.cdx.json` is not mutated.
- Is invoked identically by `just build-image <name>` (locally) and by `.github/workflows/build.yml` (in CI), so enrichment behaves the same in both places.

## Implements

- `common-sbom-enrichment` — enrichment runs on the build-produced CycloneDX file, writing to a sibling `.enriched.cdx.json`. The raw SBOM is preserved.
- `common-local-ci-parity` — the tool is provided by the Nix devShells (`default` and `ci` both include `sbomifyAction`), and the wrapping script (`common/lib/scripts/enrich-sbom`) is shared between local and CI invocations.

## Files / Tools Involved

- `common/pkgs/sbomify-action/` — Nix package definition for the sbomify-action CLI. Sourced from the `sbomify-action-src` flake input.
- `flake.nix` — declares `sbomify-action-src` as a flake input pinned to a specific git tag (e.g. `github:sbomify/sbomify-action/v26.1.0`). The default and `ci` devShells include `sbomifyAction`.
- `flake.lock` — records the resolved revision of `sbomify-action-src`.
- `common/lib/scripts/enrich-sbom` — the wrapping bash script. Handles the `SBOMIFY_TOKEN`-unset graceful skip, formats the CLI invocation, and writes to a separate output file (does not overwrite the input).
- `common/lib/scripts/build-and-push` — orchestrates `nix build → patchedSbom → enrich-sbom → scan-sbom`. Calls `enrich-sbom` for each image as part of the unified build.
- `Justfile` (`build-image` recipe) — local entry point; calls `enrich-sbom` per image after the Nix build, unless `--no-enrich` is passed.
- `.github/workflows/build.yml` — CI entry point; runs the same `build-and-push` script under the `ci` devShell with `SBOMIFY_TOKEN` injected from repo secrets.

## Procedure: bumping the sbomify-action version

1. Update the `sbomify-action-src` URL in `flake.nix` to the new git tag (e.g. `github:sbomify/sbomify-action/v26.2.0`).
2. Run `nix flake update sbomify-action-src` to refresh `flake.lock`.
3. If the package's Nix expression at `common/pkgs/sbomify-action/` carries upstream-version-specific overrides (patches, vendored hashes, dependency pins), update them.
4. Re-run `just build-image postgres` (or any image) and verify the enriched output `.local/build/sboms/postgres.enriched.cdx.json` is valid CycloneDX (`jq . < ...enriched.cdx.json | head`) and that components were enriched (look for `licenses`, `description`, `externalReferences` fields populated where they were absent in the raw SBOM).
5. Commit `flake.nix`, `flake.lock`, and any `common/pkgs/sbomify-action/` change together.

## Procedure: replacing sbomify-action with a different enrichment tool

1. Confirm the candidate tool operates on CycloneDX in place (or can be wrapped to). If it only enriches SPDX, it does not fit — enrichment here runs on the CycloneDX produced directly by the Nix build, by design.
2. Add the new tool to `common/pkgs/<tool>/` as a Nix package (or pull from nixpkgs if already there) and add it to the `default` and `ci` devShells in `flake.nix`.
3. Replace the `sbomify-action` invocation in `common/lib/scripts/enrich-sbom` with the new tool's equivalent CLI. Preserve the contract: input is `.cdx.json`, output is `.enriched.cdx.json`, no mutation of the input, graceful skip if a required env variable is unset.
4. Update CI workflow secrets (`SBOMIFY_TOKEN` → the new tool's auth env var) in `.github/workflows/build.yml`.
5. Remove `common/pkgs/sbomify-action/` and the `sbomify-action-src` flake input once nothing references them.

## Notes

- The enrichment step requires network access to public package registries (PyPI, deps.dev, ClearlyDefined, Repology, etc.) plus the sbomify API. The CI `build` job already has registry access; the `SBOMIFY_TOKEN` secret is injected via `secrets.SBOMIFY_TOKEN` in `.github/workflows/build.yml`.
- Local users without `SBOMIFY_TOKEN` get the raw SBOM only — `just build-image` does not fail, and the enriched file is identical to the raw. This keeps onboarding friction low.
- Enrichment is best-effort: private or vendored components for which no public metadata exists remain as they were. This is expected behaviour; it must not fail the build.
- The release pack (the compliance ZIP assembled at pre-release) ships the raw `.cdx.json` and the enriched `.enriched.cdx.json` per image.
