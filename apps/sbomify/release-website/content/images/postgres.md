---
title: "postgres"
description: "PostgreSQL container image with compliance artifacts."
weight: 1
---

## Overview

A compliance-ready PostgreSQL container image built with Nix. This image
is based on upstream nixpkgs PostgreSQL with additional CVE patches and
license compliance configuration applied via custom Nix packages.

## Pull command

```bash
docker pull ghcr.io/wellmaintained/postgres:latest
```

## Base packages

- PostgreSQL (from `common/pkgs/` with upstream patches)
- Runtime dependencies managed via Nix

## CVE patches applied

*This section will be populated by CI from build artifacts.*

| CVE ID | Severity | Patch source | Upstream fix version |
|--------|----------|-------------|---------------------|
| — | — | — | — |

## Dependency graph

*Rendered dependency visualization will appear here once CI integration is complete.*

## License breakdown

*License analysis from SBOM will appear here once CI integration is complete.*

## Quality scores

*sbomqs scores will appear here once CI integration is complete.*

## Vulnerability summary

*Vulnerability scan results will appear here once CI integration is complete.*

## Links

- [View on Trust Centre](https://trust.sbomify.com) — machine-readable SBOM access
- [View on GHCR](https://github.com/wellmaintained/packages/pkgs/container/postgres) — container registry
