# packages

@.claude/principles.md

Wellmaintained Nix-based image pipeline producing OCI images and
authoritative CycloneDX SBOMs for the sbomify application.

## Structure

- `flake.nix` / `flake.lock` — Nix flake; defines packages, image
  derivations, and devShells (`default`, `ci`, `sbomify`).
- `common/images/*.nix` — Common image Nix definitions (postgres,
  redis, minio).
- `common/lib/nix-compliance-inator/` — Nix overlay producing
  compliance-grade OCI images with patched CycloneDX SBOMs.
- `common/lib/scripts/` — Build, scan, enrich, and release scripts;
  shared by local `just` targets and CI workflows.
- `common/pkgs/` — Nix-packaged tooling (sbomify-action, sbomqs,
  sbomlyze, minimal-busybox).
- `apps/sbomify/images/*.nix` — sbomify application image Nix
  definitions (sbomify-app, sbomify-keycloak, etc.).
- `apps/sbomify/release-website/` — Hugo release website.
- `apps/sbomify/deployments/` — Compose deployment artefacts.
- `.github/image-matrix.json` — Image name → Nix package → sbomify
  component-id mapping (consumed by the build matrix).
- `.github/workflows/` — `build.yml` (PR build), `pre-release.yml`
  (collection assembly on merge), `deploy-release-website.yml`
  (download + publish), `cleanup-stale-images.yml`,
  `sbom-quality-gate*.yml`.
- `Justfile` — Local task runner; recipes invoke the same
  `common/lib/scripts/*` that CI runs.
- `docs/adrs/` — Architecture decision records.

## Prerequisites

- Nix (with flakes enabled)
- direnv (loads `nix develop` automatically via `.envrc`)
- Just

## Quick Start

```
just build-image postgres        # Build one image + CycloneDX SBOM (and enrich if SBOMIFY_TOKEN set)
just build-image --all           # Build all images in .github/image-matrix.json
just release-website-serve       # Serve the release website locally
```
