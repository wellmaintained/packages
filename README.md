# packages

Curated set of Nix-built minimal OCI container images.

## Available Images

| Image | Description |
|-------|-------------|
| `ghcr.io/wellmaintained/postgres` | PostgreSQL 17 database |
| `ghcr.io/wellmaintained/redis` | Redis server |
| `ghcr.io/wellmaintained/minio` | MinIO object storage server |
| `ghcr.io/wellmaintained/minio-client` | MinIO client (mc) |

All images are built from nixpkgs using `dockerTools.buildLayeredImage`, producing minimal, reproducible containers with OCI metadata labels.
