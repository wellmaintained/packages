---
title: "Provenance"
description: "Build provenance, SLSA level evidence, and image verification for this release."
weight: 5
sidebar:
  open: true
---

This release claims [SLSA Build Level 3](https://slsa.dev/spec/v1.0/levels#build-l3)
under the SLSA v1.0 specification. Every container image has authenticated
provenance attached as an OCI attestation, signed via Sigstore keyless signing.

<small>Sample data from postgres image. Full release data will be populated
by the extraction script across all {{< param-image-count >}} images.</small>

## SLSA Build Level 3

[SLSA](https://slsa.dev) (Supply-chain Levels for Software Artifacts) is a
framework for reasoning about supply chain security. Build Level 3 is the
highest level in the Build track (v1.0), requiring hardened, isolated builds
with authenticated, non-falsifiable provenance.

| Requirement | How We Meet It |
|-------------|----------------|
| Provenance exists | SLSA provenance attached as OCI attestation to every image |
| Hosted build platform | [GitHub Actions](https://github.com/wellmaintained/packages/actions) |
| Authenticated provenance | [Sigstore](https://sigstore.dev) keyless signing via GitHub OIDC — no long-lived keys |
| Isolated builds | [Nix](https://nixos.org/) sandbox + ephemeral GitHub Actions runners |

### Reproducibility

Nix builds are hermetic — the same inputs produce identical outputs. All
package inputs are pinned via `flake.lock`, ensuring bit-for-bit reproducible
builds from source. Verified reproducibility (independent rebuild and digest
comparison) is possible but not yet implemented.

## Image Provenance

| Image | Digest | Builder | Source Commit | Signed |
|-------|--------|---------|---------------|--------|
| postgres | `sha256:a1b2c3d4...` | [GitHub Actions](https://github.com/wellmaintained/packages/actions/runs/12345) | [`abc1234`](https://github.com/wellmaintained/packages/commit/abc1234) | Sigstore (keyless) |
| redis | `sha256:...` | GitHub Actions | — | Sigstore (keyless) |
| minio | `sha256:...` | GitHub Actions | — | Sigstore (keyless) |
| sbomify-app | `sha256:...` | GitHub Actions | — | Sigstore (keyless) |
| sbomify-keycloak | `sha256:...` | GitHub Actions | — | Sigstore (keyless) |
| sbomify-caddy-dev | `sha256:...` | GitHub Actions | — | Sigstore (keyless) |
| sbomify-minio-init | `sha256:...` | GitHub Actions | — | Sigstore (keyless) |

## Verification

All images are signed with [Sigstore](https://sigstore.dev) keyless signing
using GitHub Actions' OIDC identity. You can verify signatures and attestations
using [cosign](https://github.com/sigstore/cosign):

### Verify image signature

```bash
cosign verify \
  --certificate-identity-regexp="https://github.com/wellmaintained/packages/" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/wellmaintained/packages/postgres:sbomify-v26.1.0-20260405.6
```

### Verify SLSA provenance

```bash
cosign verify-attestation \
  --type slsaprovenance \
  --certificate-identity-regexp="https://github.com/wellmaintained/packages/" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/wellmaintained/packages/postgres:sbomify-v26.1.0-20260405.6
```

### Verify SBOM attestation

```bash
cosign verify-attestation \
  --type cyclonedx \
  --certificate-identity-regexp="https://github.com/wellmaintained/packages/" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/wellmaintained/packages/postgres:sbomify-v26.1.0-20260405.6
```

### Source

All source code for this release is available at the tagged release:

- [Source tree](https://github.com/wellmaintained/packages/tree/sbomify-v26.1.0-20260405.6) — browse the full source at this release tag
- [Nix flake](https://github.com/wellmaintained/packages/blob/sbomify-v26.1.0-20260405.6/flake.nix) — the top-level build definition
- [Image definitions](https://github.com/wellmaintained/packages/tree/sbomify-v26.1.0-20260405.6/apps/sbomify/images) — per-image Nix expressions
