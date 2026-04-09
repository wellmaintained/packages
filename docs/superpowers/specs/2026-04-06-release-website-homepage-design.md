# Release Website Homepage Design

Date: 2026-04-06

## Context

The release website at `wellmaintained.github.io/packages/sbomify/` is the public-facing site for the sbomify application release built by wellmaintained/packages. It was previously branded as "wellmaintained/packages" with an image-centric structure. This design restructures it as a release-centric site branded as sbomify.

## Audiences and Use Cases

Four audiences visit this site:

1. **Operators** — "I want to deploy this release." They need the release artifacts: container images, docker-compose.yml, digests, and configuration guidance.

2. **Auditors** — "I need compliance evidence." They need SBOMs, vulnerability scans, VEX statements, remediation SLA, and a downloadable compliance pack ZIP.

3. **Evaluators** — "Where does this stuff come from?" They want to understand provenance: nixpkgs-unstable base, CVE overlays, custom packages, build pipeline, with links to the exact tagged source.

4. **Robots** — Automated tools discovering machine-readable documents: security.txt, CSAF advisories, OpenVEX, sitemap.

## Site Structure

### URL

`wellmaintained.github.io/packages/sbomify/` — the `/sbomify/` subdirectory makes clear this is the sbomify application within the packages repo.

### Navbar

- **Left**: Package logo (SVG) + two-line title:
  - Line 1 (bold): `sbomify | v26.1.0`
  - Line 2 (small, linked): `by wellmaintained/packages` → links to GitHub repo
- **Right**: Release | Compliance | Provenance

### Homepage

**Hero banner:**
- Headline: `sbomify | v26.1.0`
- Subtitle line 1: "A Software Bill of Materials (SBOM) and document management platform application."
- Subtitle line 2 (smaller): "This is a wellmaintained/packages distribution of the hosted app.sbomify.com service."
  - "wellmaintained/packages" links to `https://github.com/wellmaintained/packages`
  - "app.sbomify.com" links to `https://app.sbomify.com`
- No GitHub badge — provenance links handle that

**Three feature cards:**

#### Release card
- Title: "📦 Release"
- Content: "7 container images" followed by image names (postgres · redis · minio · sbomify-app · sbomify-keycloak · sbomify-caddy-dev · sbomify-minio-init)
- Version tag (linked to GitHub Release page): `sbomify-v26.1.0-20260405.6`
- Links: docker-compose.yml, "All images & digests →"

#### Compliance card
- Title: "📋 Compliance"
- Content: Links to SBOMs (CycloneDX), Vulnerability scans, VEX statements, Remediation SLA
- Summary: "SLA: 7 days critical · 30 days high"
- Link: "⬇ Compliance pack ZIP →"

#### Provenance card
- Title: "🔍 Provenance"
- Content: "Built from nixpkgs-unstable", "CVE overlays applied", "Custom packages", "Image build pipeline" — each linked to release-specific files/directories at the tagged source
- Source tag (linked to GitHub source tree at tag): `sbomify-v26.1.0-20260405.6`
- Link: "How it's built →"

**Footer:**
- Machine-discoverable links: `security.txt · CSAF advisories · OpenVEX · Sitemap`

### Inner Pages

- **Release page** (`/release/`): Full detail — images table with tags, digests, pull commands. Docker-compose usage. Configuration guide (placeholder for now). Support period declaration.
- **Compliance page** (`/compliance/`): Per-release compliance evidence. Existing sub-pages: audit-pack, sla-policy, vulnerability-status, vex-statements.
- **Provenance page** (`/provenance/`): Explanatory narrative about the build pipeline with release-specific links to nixpkgs commit, CVE overlay files, Nix derivations, all at the tagged release SHA.

## Data Flow

Release-specific data (version, tag, date, images, digests) comes from `data/release.json`, which is:
- **In CI**: Generated from the GitHub Release event payload before `hugo --minify`
- **Locally**: A static placeholder file with the latest release data for development

## Key Decisions

- **Branding**: Site is "sbomify", not "wellmaintained/packages". The distributor identity is in the navbar subtitle and hero text.
- **Three use cases, not three content types**: Cards are organized by what the visitor wants to do (deploy, audit, understand provenance), not by content category.
- **Provenance is explanatory with release-specific links**: The narrative explains the build approach; the links point to the exact tagged source for this release.
- **Footer for robots**: Machine-readable documents (security.txt, CSAF, OpenVEX) live in the footer, not competing with the main cards.
- **No deploy instructions on homepage**: The Release card lists artifacts; the Release detail page explains how to use them.
