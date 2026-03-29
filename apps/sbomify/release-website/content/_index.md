---
title: "wellmaintained/packages"
description: "Compliance-ready container images with SBOMs, quality scores, and audit evidence."
---

## What is this site?

This is the release website for [wellmaintained/packages](https://github.com/wellmaintained/packages) — a repository that builds compliance-ready OCI container images using Nix.

Every image built by this pipeline comes with:

- **CycloneDX SBOMs** — machine-readable software bills of materials
- **Quality scores** — sbomqs ratings for SBOM completeness
- **Vulnerability summaries** — known CVEs and patch status
- **License breakdowns** — full dependency license analysis

## Site sections

### [Container Images](/images/)
Browse the catalog of available container images. Each image page shows its
dependencies, applied CVE patches, license breakdown, and quality scores.

### [Compliance & Audit](/compliance/)
Auditor-facing compliance evidence. Download audit evidence packs formatted
for GRC tools like Vanta and Drata.

### [Deployment Guides](/guides/)
Getting started guides and deployment documentation.

## How it works

Images are built with Nix using the `buildCompliantImage` API from
[nix-compliance-inator](https://github.com/wellmaintained/packages). This
ensures every image is reproducible and ships with complete compliance
artifacts. CI publishes images to GHCR and compliance data to both this
site and the [sbomify Trust Centre](https://trust.sbomify.com).
