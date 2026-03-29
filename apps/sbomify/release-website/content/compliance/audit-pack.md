---
title: "Audit Evidence Pack"
description: "Downloadable compliance evidence packs for GRC tools."
---

## What's in the audit pack?

Each release produces a downloadable ZIP containing everything a GRC tool
(Vanta, Drata, etc.) needs for compliance evidence:

- **CycloneDX SBOMs** — one per image
- **SPDX SBOMs** — alternative format for tools that prefer it
- **Quality score reports** — sbomqs ratings
- **Vulnerability reports** — CVE scan results
- **License summaries** — per-image license breakdown
- **Manifest file** — explains contents and format

## Downloads

*Audit evidence packs will be available here once CI integration is complete.
Each release will produce a downloadable ZIP per image and per release.*

## Format

Evidence packs are structured for direct import into GRC tools:

```
audit-pack-v1.0.0/
  manifest.json
  postgres/
    sbom.cdx.json      (CycloneDX)
    sbom.spdx.json      (SPDX)
    quality-scores.json
    vulnerabilities.json
    license-summary.json
  redis/
    ...
```
