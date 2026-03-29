# 0004. Repo structure and demo narrative

Date: 2026-03-29

## Status

proposed (revised after design review)

## Context

The wellmaintained/packages repo is being demoed to the creators of sbomify.
The repo currently works well technically — Nix builds compliant OCI images
with CycloneDX SBOMs, CI quality-gates them, and promotion preserves artifact
integrity. But the directory structure doesn't tell this story. A visitor
looking at the top-level layout sees:

```
images/          <- 3 common images (postgres, redis, minio)
deployments/     <- sbomify-specific images buried 2 levels deep
sboms/           <- raw JSON files with no context
nix-compliance-inator/  <- the engine, but unclear how it connects
pkgs/            <- custom Nix packages, but relationship to images unclear
```

### Three tiers of value

- **Tier A — Common packages and containers**: Custom Nix packages that
  patch upstream nixpkgs (CVE fixes, configuration to ensure license
  compliance — e.g. switching off usage of copyleft components), and
  infrastructure container images built from those packages. Reusable by
  anyone. Examples: postgres, redis, minio — and in future, base packages
  like python and node.

- **Tier B — App-specific packages and containers**: Application-specific
  Nix packages and container images built on top of Tier A bases. These
  demonstrate how you would package a custom application (like sbomify)
  with a fork of wellmaintained/packages — leveraging the common packages
  and build tooling for your application. Examples: sbomify-app,
  sbomify-frontend, sbomify-keycloak.

- **Tier C — Release website with compliance evidence**: A Hugo-based
  GitHub Pages site published alongside every release. Contains the image
  catalog, SBOM visualizations, compliance audit evidence packs, and
  deployment guides. Complements (and includes richer views than) the
  sbomify Trust Centre.

### Design goals

1. **Fork-friendly**: A team forking this repo should immediately see what
   to keep (common infrastructure, build tooling) vs what to replace (the
   app-specific layer). The top-level layout should make this obvious.

2. **Intermediate patching layer visible**: Custom Nix packages are where
   upstream patching happens (CVE fixes, license compliance configuration). These
   packages then flow into container images. This two-step process
   (patch the package, compose into a container) should be visible in the
   directory structure, not hidden.

3. **Compliance as a built artifact**: SBOMs, quality scores, and audit
   evidence are outputs of the build pipeline — not files committed to the
   repo. They belong on a release website that CI publishes, not in a
   `compliance/` directory that goes stale.

4. **Trust Centre integration**: The sbomify Trust Centre
   (trust.sbomify.com) is one distribution channel for compliance data.
   The release site is another, with richer visualizations and downloadable
   audit evidence packs for GRC tools like Vanta.

### Current problems

1. **No fork-friendly separation.** Common infrastructure and sbomify-specific
   code are interleaved. A fork wouldn't know what to keep vs replace.

2. **The patching layer is invisible.** `pkgs/` exists at the root but its
   relationship to images is unclear. The story "we patch upstream packages,
   then build containers from them" isn't reflected in the layout.

3. **Tier B is hidden.** sbomify images live under `deployments/sbomify/images/`
   — a path that suggests deployment configs, not image definitions.

4. **Compliance evidence is raw committed JSON.** `sboms/` contains CycloneDX
   files that go stale. There's no visualization, no quality scoring, no
   auditor-facing view, no way to hand an evidence pack to a GRC tool.

5. **No narrative structure.** The README lists 3 common images. It doesn't
   mention sbomify, doesn't explain the compliance pipeline, and doesn't
   guide a visitor through the value tiers.

## Decision

### 1. Top-level split: common vs apps

The primary organizational axis is **reusable infrastructure vs app-specific**.
This makes the fork story obvious: keep `common/`, replace `apps/`.

```
common/                      <- KEEP when forking: upstream patches + infra + tooling
  pkgs/                      <- Custom Nix packages (patching layer)
    python/                  <- e.g. Python with CVE-2026-XXXX patched
    ...
  images/                    <- Infrastructure container images
    postgres.nix
    redis.nix
    minio.nix
  lib/                       <- Build tooling
    nix-compliance-inator/   <- The compliance build engine (buildCompliantImage API)
    tests/                   <- Spec tests
    scripts/                 <- CI helper scripts

apps/                        <- REPLACE when forking: your app goes here
  sbomify/                   <- sbomify-specific (rename for your app)
    pkgs/                    <- App-specific Nix packages
    images/                  <- App container images
      sbomify-app.nix
      sbomify-keycloak.nix
      sbomify-caddy-dev.nix
      sbomify-minio-init.nix
    deployments/             <- Compose configs, runtime operational concerns
      compose/
      build-support/         <- Build-time support files (e.g. collectstatic settings)
      sbom-src/              <- SBOM enrichment sources (supplier, license metadata)
    release-website/         <- Hugo source for this app's release website
      ...

.github/                     <- ADAPT: CI workflows
  workflows/

docs/                        <- ADRs, design docs (developer-facing)
  adrs/
```

**Fork instructions:**
1. `common/` — keep pulling upstream updates. This is where wellmaintained's
   value lives (patched packages, infrastructure images, build tooling).
2. `apps/sbomify/` — delete, create `apps/yourapp/`. Same structure: your
   packages, images, deployments, and release website.
3. `.github/` — adapt workflows to your app name and registry.

### 2. Intermediate Nix packages as the patching layer

Custom Nix packages are where upstream patching happens. The directory
structure makes this visible:

```
common/pkgs/python/          <- Patched Python with CVE fixes
common/images/some-thing.nix <- Uses common/pkgs/python
apps/sbomify/images/app.nix  <- Also uses common/pkgs/python
```

This gives the compliance narrative real teeth: you can point to a CVE patch
in `common/pkgs/python/`, then trace it through the SBOM of every image that
uses it. For auditors: "we patch ahead of upstream, and you can see exactly
which images got the fix."

Each custom package should document:
- What upstream package it overrides
- What patches are applied and why (CVE IDs, license compliance config)
- When the patch can be dropped (upstream version that includes the fix)

### 3. Build tooling in common/lib/

nix-compliance-inator moves from a top-level directory to `common/lib/`.
Tests and CI helper scripts consolidate here too. Placing it under `common/`
makes it clear this is part of the reusable infrastructure that forks keep.

```
common/lib/
  nix-compliance-inator/     <- buildCompliantImage API (self-contained flake)
  tests/                     <- ShellSpec tests (currently in spec/)
  scripts/                   <- CI helper scripts (currently in bin/)
```

nix-compliance-inator remains a self-contained flake consumed via
`path:./common/lib/nix-compliance-inator` in the parent flake. Its role is
the build engine — part of what makes `common/` valuable to forks.

### 4. Release website via Hugo + GitHub Pages

Instead of committing compliance artifacts to the repo, CI publishes a
release website to a `gh-pages` branch. The site is the full-service
compliance portal — not just a catalog.

The Hugo source lives in `apps/<name>/release-website/` because the release
website is inherently app-specific — it catalogs that app's images, that
app's compliance evidence, and that app's deployment guides. A fork creating
`apps/yourapp/` would create their own `release-website/` alongside it.

**Site structure:**

```
/                            <- Landing: what is wellmaintained/packages
/images/                     <- Catalog: every image, tags, pull commands
/images/postgres/            <- Per-image detail:
                                - Description and base packages
                                - CVE/license patches applied
                                - Dependency graph visualization
                                - License breakdown
                                - sbomqs quality scores
                                - Vulnerability summary
/compliance/                 <- Auditor landing: methodology, standards
/compliance/audit-pack/      <- Downloadable evidence packs per release:
                                - CycloneDX SBOMs
                                - SPDX SBOMs
                                - Quality score reports
                                - Vulnerability reports
                                - License summaries
                                - Formatted for GRC tool import (Vanta, Drata)
/guides/                     <- Deployment guides, getting started
```

**Key features:**

- **SBOM visualizations**: Dependency graphs, component trees, license
  breakdowns — not raw JSON. Auditors and evaluators see rendered views.

- **Compliance audit evidence pack**: One-click downloadable ZIP per image
  or per release. Contains everything a GRC tool needs: SBOMs in multiple
  formats, quality scores, vulnerability reports, license summaries. A
  manifest file explains what's inside.

- **Per-image CVE patch notes**: For each image, shows what upstream
  packages were patched, which CVEs were fixed, and when patches can be
  dropped. Traceable from package to container to SBOM.

**CI publishes to both channels:**

```
CI build
  |
  +-> Build images -> push to GHCR
  +-> Generate SBOMs + quality scores + vulnerability data
  |     |
  |     +-> Upload to sbomify (feeds Trust Centre)
  |     +-> Render Hugo site (from apps/<name>/release-website/) -> publish to gh-pages
  |
  +-> Add Product Links in sbomify -> Trust Centre links to release site
```

### 5. Trust Centre integration

The sbomify Trust Centre and the release website contain overlapping
compliance data but serve different purposes:

| Concern | Release site | Trust Centre |
|---------|-------------|--------------|
| SBOM visualizations | Rich (graphs, trees) | Basic (download links) |
| Audit evidence packs | Yes (ZIP for GRC tools) | No |
| TEA API (machine-readable) | No | Yes |
| Assessment badges | No | Yes |
| CVE patch notes | Yes (per-image detail) | No |
| Deployment guides | Yes | No |
| Product Links ecosystem | Linked from | Links to |
| Custom domain | gh-pages | trust.yourdomain.com |

**Bidirectional linking:**
- Release site -> Trust Centre: "View on Trust Centre" links for
  machine-readable access and TEA API discovery
- Trust Centre -> Release site: Product Links (type: website, download,
  documentation, release_notes) pointing to the release site

Both are fed from the same CI pipeline, so compliance data never diverges.

### 6. Keep Tier B (sbomify) in this repo

The sbomify container image definitions belong in `apps/sbomify/`, because:

- They depend on `common/lib/nix-compliance-inator`'s `buildCompliantImage` API
- They share the same CI pipeline as common images
- They consume `common/pkgs/` overlays
- Having them here IS the dog-fooding story: packaging sbomify's application
  with the same compliance pipeline offered to everyone

### Relation to other ADRs

Builds on ADR 0002 (`buildCompliantImage` API) which defines how images
and compliance artifacts are co-derived. The `common/` and `apps/` image
specs both use `buildCompliantImage`, and the release website visualizes
the compliance output it generates.

Builds on ADR 0003 (build once, promote on merge) which defines the CI
pipeline. The release website is published as part of the promote step,
ensuring it always reflects the latest promoted images.

## Consequences

### Benefits

- **Fork-friendly at a glance.** `common/` vs `apps/` is immediately
  obvious. Fork instructions are simple: keep `common/`, replace `apps/`.

- **Patching layer is visible.** `common/pkgs/` and `apps/sbomify/pkgs/`
  show where upstream modifications happen. The CVE patch -> package ->
  container -> SBOM trace is navigable in the directory tree.

- **Compliance evidence is always fresh.** The release website is built
  by CI, not committed to the repo. No staleness, no divergence from
  actual build output.

- **Auditors get what they need.** The audit evidence pack is a
  one-click download formatted for GRC tools. No asking developers to
  extract SBOMs from CI artifacts.

- **The demo tells a complete story.** Three URLs: the repo (how we
  build), the release site (what we produce + compliance proof), the
  Trust Centre (machine-readable standards compliance). Each reinforces
  the others.

- **Dog-fooding is front and center.** `apps/sbomify/` living alongside
  `common/` shows sbomify's own images go through the identical pipeline.

### Trade-offs

- **File moves require updating flake.nix imports.** Moving image specs
  to `common/images/` and `apps/sbomify/images/`, and nix-compliance-inator
  to `common/lib/`, means updating import paths in `flake.nix`.
  Straightforward but touches the central build definition.

- **Hugo adds a build dependency.** The release site needs Hugo in the CI
  environment and a gh-pages publishing step. This is well-trodden ground
  but adds CI complexity.

- **Duplicate compliance data.** The same SBOMs and scores appear on both
  the release site and the Trust Centre. This is intentional (different
  audiences, different features) but means two publishing pipelines to
  maintain.

- **`apps/sbomify/deployments/` nesting is deeper.** Compose configs move
  from `deployments/sbomify/compose/` to `apps/sbomify/deployments/compose/`.
  One more directory level, but the grouping is clearer.

### Future considerations

- **Tier A expansion.** As common images grow (python, node base images),
  `common/images/` may benefit from subdirectories by category
  (databases/, runtimes/, tools/).

- **Multiple apps.** The `apps/` pattern supports multiple app-specific
  directories (e.g. `apps/sbomify/`, `apps/another-customer/`), each
  with their own packages, images, and deployments.

- **SBOM diff between releases.** The release website could show what
  changed between releases — new dependencies, resolved vulnerabilities,
  updated patches.

- **Automated GRC tool integration.** Beyond downloadable ZIPs, the
  release site could offer direct API integration with Vanta, Drata,
  or other GRC tools for automated evidence collection.

- **SPDX alongside CycloneDX.** The audit evidence pack can include
  both formats. Some GRC tools prefer one over the other.
