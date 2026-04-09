---
title: "Quickstart"
description: "Deploy this release and download the compliance audit pack."
weight: 0
sidebar:
  open: true
---

## Deploy

7 container images · [sbomify-v26.1.0-20260405.6](https://github.com/wellmaintained/packages/releases/tag/sbomify-v26.1.0-20260405.6)

Download the docker-compose.yml for this release and start the stack:

```bash
curl -LO https://github.com/wellmaintained/packages/releases/download/sbomify-v26.1.0-20260405.6/docker-compose.yml
docker compose up -d
```

> ⚠️ Review and update `SECRET_KEY` and other credentials before production use.

See [Dependencies](../dependencies/) for full image list, digests, and SBOMs.

## Audit Pack

*Coming soon — audit pack generation not yet in CI.*

The audit evidence pack will bundle all compliance artifacts into a single
downloadable ZIP:

- [Dependencies](../dependencies/) — CycloneDX SBOMs for all images
- [Vulnerabilities](../vulnerabilities/) — Grype CVE scans with VEX triage
- [Licenses](../licenses/) — License notices and source disclosure
- [Provenance](../provenance/) — SLSA provenance attestations

## Previous Releases

Historical releases and compliance bundles are available at
[GitHub Releases](https://github.com/wellmaintained/packages/releases).
