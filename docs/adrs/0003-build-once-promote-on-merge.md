# 0003. Build once, promote on merge

Date: 2026-03-24

## Status

accepted

## Context

The current CI pipeline builds images and SBOMs in separate workflows with
different triggers:

- `build-oci-images.yml` builds 7 OCI images on push to main only, tagging
  and pushing to GHCR.
- `sbom-generate.yml` builds SBOMs on both PRs and main pushes, uploading
  enriched SBOMs as GitHub Actions artifacts.
- `sbom-quality-gate.yml` scores PR SBOMs and blocks merging on regression.
- `sbom-upload-sbomify-com.yml` uploads SBOMs to sbomify.com after main push.

This architecture has two structural problems:

**1. The artifact that ships is not the artifact that was tested.** Images are
rebuilt from scratch on merge to main. The SBOM quality-gated on the PR was
generated from a different Nix evaluation than the image pushed to GHCR. Nix
is deterministic in theory, but flake inputs, timestamps, and upstream
package updates can cause drift between evaluations.

**2. Images and SBOMs are built in separate workflows.** The 7-image matrix
is duplicated across `build-oci-images.yml` and `sbom-generate.yml`. Adding
a new image means editing both workflows and keeping the matrix entries in
sync.

The desired property is: **the artifact that was tested IS the artifact that
ships.** This requires building once on the PR, quality-gating the built
artifacts, and promoting the exact same artifacts (by digest) on merge —
with no rebuild.

### Constraints

- Images are built with Nix (`nix build .#<package>`) and loaded via
  `docker load`, not built with `docker build`. This means `docker buildx`
  attestation features don't apply directly.
- The Nix store cache (Blacksmith stickydisk) makes rebuilds fast but
  doesn't eliminate the drift risk.
- GHCR is the existing registry. The repo is public, so GHCR storage is
  free.

## Decision

### 1. Combine image and SBOM builds into a single workflow

A new `build.yml` workflow replaces both `build-oci-images.yml` and
`sbom-generate.yml`. It runs on PRs only, and for each image in the
matrix:

1. Builds the compliant image package via `nix build .#<name>`
   — this single evaluation produces `result.image` (the OCI image)
   and `result.metadata.sbom.cyclonedx-1-6` (the CycloneDX SBOM),
   as defined by `buildCompliantImage` in ADR 0002
2. Enriches the SBOM via sbomify-action
3. Pushes the image to GHCR with a PR-specific tag
4. Signs the image via cosign
5. Attaches the enriched SBOM as a signed attestation via cosign

One `nix build`, one evaluation, one matrix entry per image. The SBOM is
structurally derived from the image contents — drift is impossible because
both come from the same derivation.

### 2. Tag PR images in GHCR with `pr-<number>-<sha>`

On every PR commit, the built image is pushed to GHCR with a tag encoding
the PR number and commit SHA:

```
ghcr.io/wellmaintained/packages/<name>:pr-<number>-<sha7>
```

This provides:
- Traceability from any image back to a specific PR and commit
- A stable reference for the quality gate to score against
- No collision between concurrent PRs

### 3. Promote on merge by re-tagging the digest

A separate `promote.yml` workflow triggers on push to main. For each image
in the matrix, it runs `bin/promote-image`, a tested shell script that:

1. Resolves the merge commit back to a PR number and head SHA
2. Looks up the image digest from the PR-specific tag in GHCR
3. Re-tags that exact digest with the release tags:
   - `latest`
   - `<upstream-version>` (e.g. `7.4.2`)
   - `<upstream-version>-<calver>` (e.g. `7.4.2-202603241006`)
4. Uploads the SBOM to sbomify.com

No rebuild occurs. The promoted image is bit-for-bit identical to the one
that passed the quality gate.

The promotion logic lives in `bin/promote-image` — a self-contained script
that can be tested locally and in CI independently of the GitHub Actions
workflow YAML. The workflow file is a thin wrapper that sets up
authentication and calls the script.

### 4. Attach SBOMs via cosign attest with keyless signing

Each image gets two cosign operations after being pushed to GHCR:

```bash
# Sign the image (keyless via Fulcio OIDC)
cosign sign --yes ghcr.io/wellmaintained/packages/<name>@sha256:<digest>

# Attach SBOM as a signed in-toto attestation
cosign attest --yes \
  --predicate ./<name>.enriched.cdx.json \
  --type cyclonedx \
  ghcr.io/wellmaintained/packages/<name>@sha256:<digest>
```

Keyless signing uses GitHub Actions' OIDC identity — no key management
required. The `id-token: write` permission is the only addition needed.

Cosign attestations are stored as OCI referrers keyed by the image
**digest**, not by tag. When the image is re-tagged during promotion, the
attestation remains discoverable and verifiable through any tag pointing to
that digest. This is fundamental to cosign's security model: digests are
immutable, tags are mutable pointers.

### 5. Keep the quality gate as a separate workflow

`sbom-quality-gate.yml` continues to run as a `workflow_run` consumer
triggered by the build workflow on PRs. Its job is unchanged: score the
PR's SBOM, compare against the main baseline, and block merging on
regression.

The quality gate does not need to change — it already consumes SBOM
artifacts. The only difference is that the artifacts now come from the
combined build workflow instead of a standalone SBOM generation workflow.

### 6. Clean up PR images after merge or close

PR-specific tags accumulate in GHCR. A `cleanup-pr-images.yml` workflow
triggers on `pull_request: [closed]` and deletes images tagged with the
closed PR's number using the GitHub Packages API:

```bash
# For each image in the matrix:
gh api "/orgs/wellmaintained/packages/container/packages%2F<name>/versions" \
  --paginate \
  --jq ".[] | select(.metadata.container.tags[]
    | startswith(\"pr-${PR_NUMBER}-\")) | .id" \
| xargs -I {} gh api --method DELETE \
  "/orgs/wellmaintained/packages/container/packages%2F<name>/versions/{}"
```

A weekly scheduled sweep catches any images missed by the event-triggered
cleanup (e.g. if the PR-close workflow fails). The sweep deletes all
`pr-*` tagged images older than 7 days.

GHCR has no built-in retention policies, so this explicit cleanup is the
only mechanism. Storage is free for public repos, so the cost risk is
negligible — this is hygiene, not cost control.

### 7. Add SLSA provenance attestation

The signing infrastructure (keyless cosign + GitHub OIDC) supports SLSA
provenance attestations at negligible additional cost. Each image gets a
provenance attestation alongside the SBOM attestation:

```bash
cosign attest --yes \
  --predicate ./provenance.json \
  --type slsaprovenance \
  ghcr.io/wellmaintained/packages/<name>@sha256:<digest>
```

The provenance predicate captures the build inputs (commit SHA, workflow
ref, runner identity) for supply chain integrity. This is generated by
the build workflow, not by an external service.

### Resulting workflow structure

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `build.yml` | pull_request | Build image + SBOM, push to GHCR, sign + attest |
| `promote.yml` | push to main | Run `bin/promote-image`: re-tag digest, upload SBOM to sbomify.com |
| `sbom-quality-gate.yml` | workflow_run (build, PR only) | Score SBOM, compare vs baseline, block on regression |
| `sbom-quality-gate-pending.yml` | pull_request | Post placeholder comment |
| `cleanup-pr-images.yml` | pull_request closed + weekly schedule | Delete PR-tagged images from GHCR |

### Relation to other ADRs

Builds on ADR 0002 (buildCompliantImage). The build workflow calls
`nix build .#<name>` once per image, which evaluates the
`buildCompliantImage` function from ADR 0002. The resulting derivation
exposes `.image` (the OCI tarball) and `.metadata.sbom.cyclonedx-1-6`
(the CycloneDX SBOM) as properties of a single build output. This
structural coupling — one build, one evaluation, image and SBOM
co-derived — is the foundation that makes build-once-promote-on-merge
possible.

## Consequences

### Benefits

- **Artifact integrity.** The image that passes the quality gate is the
  image that ships. No rebuild, no drift, no "it worked on PR" surprises.
- **Single matrix.** One workflow defines the image list. Adding an image
  means one matrix entry, not two.
- **Cryptographic provenance.** Every image is signed and has a signed
  SBOM attestation. Consumers can verify both with `cosign verify` and
  `cosign verify-attestation`.
- **Digest-based promotion.** Re-tagging by digest is an atomic pointer
  operation — no data is copied, no rebuild is needed, and the attestation
  chain is preserved.
- **Free storage.** GHCR storage for public repos is free, so PR images
  have no cost beyond cleanup hygiene.

### Trade-offs

- **PR images are public.** Images pushed to GHCR on PRs are visible to
  anyone (public repo). This is acceptable for this project but would need
  reconsideration for private/proprietary images.
- **Cosign dependency.** Signing and attestation add cosign as a CI
  dependency. Cosign is available as `pkgs.cosign` in nixpkgs (currently
  v3.0.5), so it can be managed as a Nix package like `sbomqs` and
  `sbomlyze` — no external installer action needed. If Sigstore
  infrastructure (Fulcio/Rekor) is unavailable, keyless signing fails.
  Mitigation: cosign operations could be made `continue-on-error` if
  availability becomes an issue.
- **Promotion workflow complexity.** The promote workflow must resolve the
  merge commit back to a PR to find the correct image tag. This logic
  lives in `bin/promote-image` where it can be tested independently, but
  it is inherently more involved than a simple rebuild.

### Future considerations

- **Multi-arch images.** The current pipeline builds single-arch images.
  If multi-arch support is needed, the build workflow would produce an
  OCI image index and cosign would attest the index digest.
- **Promotion gating.** Currently, merge to main triggers promotion
  automatically. A future enhancement could require explicit approval
  (e.g. a `/promote` comment or a separate "release" workflow) for
  higher-ceremony deployments.
- **SBOM format expansion.** Cosign attestations support any predicate
  type. If SPDX output is added (per ADR 0002's future considerations),
  it can be attached as a second attestation alongside the CycloneDX one.
