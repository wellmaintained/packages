---
title: "Compliance & Audit"
weight: 2
sidebar:
  open: true
---

This section provides auditor-facing compliance evidence for container images
built by wellmaintained/packages.

## Methodology

All container images are built using Nix for full reproducibility. The build
pipeline generates compliance artifacts alongside every image:

1. **CycloneDX SBOMs** — complete software bills of materials
2. **sbomqs quality scores** — SBOM completeness and quality ratings
3. **Vulnerability reports** — CVE scanning results
4. **License summaries** — dependency license analysis

## Resources

- [Audit Evidence Pack](audit-pack/) — downloadable evidence bundles for GRC tools
- [sbomify Trust Centre](https://trust.sbomify.com) — machine-readable compliance data via TEA API
