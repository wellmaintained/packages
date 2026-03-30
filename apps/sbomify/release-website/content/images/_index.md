---
title: "Container Images"
weight: 1
sidebar:
  open: true
---

Browse the catalog of container images built by this pipeline. Each image
is built with Nix for reproducibility and ships with a complete SBOM,
quality scores, and vulnerability data.

## Common Infrastructure Images

| Image | Description | Status |
|-------|-------------|--------|
| [postgres](postgres/) | PostgreSQL with upstream CVE patches | Available |
| redis | Redis with compliance metadata | Coming soon |
| minio | MinIO object storage | Coming soon |

## Application Images

Application-specific images built on top of the common infrastructure:

- sbomify-app — *coming soon*
- sbomify-keycloak — *coming soon*
- sbomify-caddy-dev — *coming soon*
