# sbomify Self-Contained Deployment

Run the full sbomify stack locally with a single command. All service
configuration is baked into the OCI images — no volume mounts or local
files required.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/wellmaintained/packages/main/apps/sbomify/deployments/compose/docker-compose.yml | docker compose -f - up
```

Or clone and run:

```bash
docker compose up
```

## Services

| Service | Description | Port |
|---------|-------------|------|
| sbomify-backend | Django app server | (internal) |
| sbomify-caddy | Caddy reverse proxy | HTTP :8000, HTTPS :8443 |
| sbomify-worker | Dramatiq background worker | (internal) |
| keycloak | Identity provider | :8180 |
| sbomify-db | PostgreSQL database | :5432 |
| sbomify-redis | Redis cache/broker | :6389 |
| sbomify-minio | MinIO object storage | API :9000, Console :9001 |

## Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| sbomify app | jdoe | foobar123 |
| Keycloak admin | admin | admin |
| MinIO | minioadmin | minioadmin |
| PostgreSQL | sbomify | sbomify |

## URLs

- **sbomify**: http://127.0.0.1:8000 (HTTP) / https://127.0.0.1:8443 (HTTPS, self-signed)
- **Keycloak**: http://127.0.0.1:8180
- **MinIO Console**: http://127.0.0.1:9001

## Teardown

```bash
docker compose down -v
```

The `-v` flag removes named volumes (database, Redis, Keycloak, MinIO data).
