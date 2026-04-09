# Release Page Design

Date: 2026-04-06

## Context

The release page at `/release/` is the operator-facing detail page for the current release. It answers: "what's in this release and how do I deploy it?" The homepage Release card links here.

## Audience

**Operators** — people who want to deploy this release. They need the artifacts (docker-compose.yml, container images) and enough metadata to verify they have the right version.

## Page Structure

### Header

`Release · sbomify · v26.1.0`

The title includes the app name and version so the page is self-identifying when bookmarked or shared.

### Release Metadata

A simple table with three rows:

| Field | Value | Link target |
|-------|-------|-------------|
| Release tag | `sbomify-v26.1.0-20260405.6` | GitHub Release page |
| App version | `v26.1.0` | Upstream sbomify release (`github.com/sbomify/sbomify/releases/tag/v26.1.0`) |
| Date | `2026-04-05` | — |

Source PR is omitted — not relevant to operators.

### Quick Start

A two-step deployment snippet:

```bash
# Download docker-compose.yml pinned to this release
curl -LO https://github.com/wellmaintained/packages/releases/download/sbomify-v26.1.0-20260405.6/docker-compose.yml

# Start the stack
docker compose up -d
```

The docker-compose.yml is a GitHub Release asset with image tags baked in (no env vars needed). A warning below the snippet reminds operators to update SECRET_KEY and other credentials before production use.

**Dependency:** The compiled docker-compose.yml release asset is tracked in sub-yak `compile-and-attach-docker-compose-to-release-0453`.

### Images Table

Lists all container images in this release with upstream versions and cross-links.

| Column | Content | Notes |
|--------|---------|-------|
| Image | Image name (bold, linked) | Links to GHCR package page |
| Upstream Version | e.g. `17.9`, `8.2.3` | Extracted from SBOMs or component tags |
| Links | compliance · provenance | Per-image deep links (top-level pages for now) |

Component tags and digests are omitted — operators use the compose file, not direct pulls. Digests are available on the GHCR page and in the compliance pack.

**Dependency:** Per-image compliance/provenance sub-pages tracked in sub-yak `per-image-compliance-provenance-links-b61a`. Until those exist, links point to top-level `/compliance/` and `/provenance/`.

### Previous Releases

One-liner linking to GitHub Releases for historical versions and compliance bundles.

## Data Requirements

The page needs from the data layer (however it's sourced):

- `tag` — release tag string
- `version` — app version string
- `date` — release date
- `images[]` — array with `name` and `upstream_version` per image

The data source (SBOMs vs custom JSON) is deferred to sub-yak `inject-release-data-into-hugo-lgqt`.

For local development, `data/release.json` provides static placeholder values. The `upstream_version` field needs to be added to the placeholder data.

## Key Decisions

- **Operator-focused, not comprehensive** — compliance and provenance are cross-links, not repeated here.
- **No pull commands** — operators use docker-compose, not direct `docker pull`.
- **No digests in the table** — available on GHCR and in compliance pack; not needed for the operator workflow.
- **No support section** — deferred for now.
- **Compiled compose file as release asset** — operators get a working docker-compose.yml without setting env vars.
- **Upstream versions, not component tags** — operators care about "postgres 17.9", not the internal tag format.

## Files to Change

- `apps/sbomify/release-website/content/release/_index.md` — rewrite page content
- `apps/sbomify/release-website/layouts/shortcodes/release-overview.html` — update metadata table
- `apps/sbomify/release-website/layouts/shortcodes/release-images.html` — simplify to upstream versions + links
- `apps/sbomify/release-website/data/release.json` — add `upstream_version` field to images
