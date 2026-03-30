# Pre-Release Workflow Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace promote.yml with a pre-release workflow that creates collection-versioned releases on merge to main (ADR-0005).

**Architecture:** On merge to main, resolve the merged PR's head SHA, query sbomify-app metadata for the app version, compute a collection version `sbomify-v{app-version}-{YYYYMMDD}.{build-number}`, tag all 7 images with that collection version via crane, extract SBOMs from attestations, upload to sbomify, and create a GitHub pre-release.

**Tech Stack:** GitHub Actions, bash scripts, crane (OCI tagging), cosign (attestation extraction), gh CLI (releases), shellspec (testing), nix (metadata)

---

## File Structure

| Action | Path | Responsibility |
|--------|------|---------------|
| Create | `common/lib/scripts/tag-collection` | Add collection version tag to image digest found by component tag |
| Modify | `common/lib/scripts/extract-sbom-attestation` | Accept `--tag` (component tag) instead of `--pr`/`--sha` |
| Create | `.github/workflows/pre-release.yml` | Orchestrate collection tagging + GitHub pre-release on merge to main |
| Delete | `.github/workflows/promote.yml` | Replaced by pre-release.yml |
| Delete | `common/lib/scripts/promote-image` | Replaced by tag-collection |
| Create | `common/lib/tests/tag_collection_spec.sh` | Tests for tag-collection script |
| Modify | `common/lib/tests/extract_sbom_attestation_spec.sh` | Update tests for --tag interface |
| Delete | `common/lib/tests/promote_image_spec.sh` | Replaced by tag_collection_spec.sh |

---

## Chunk 1: Scripts

### Task 1: Create `tag-collection` script with tests

This script replaces `promote-image`. Instead of finding images by `pr-{PR}-{SHA}` tag and adding `latest`/version tags, it finds images by component tag and adds a collection version tag.

**Files:**
- Create: `common/lib/scripts/tag-collection`
- Create: `common/lib/tests/tag_collection_spec.sh`

- [ ] **Step 1: Write the failing tests for argument validation**

Create `common/lib/tests/tag_collection_spec.sh`:

```sh
# shellcheck shell=sh
Describe "common/lib/scripts/tag-collection"

  Describe "argument validation"
    It "fails when no arguments given"
      When run common/lib/scripts/tag-collection
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --image is missing"
      When run common/lib/scripts/tag-collection --component-tag postgres-16.8-abc1234 --collection-version sbomify-v0.27.0-20260329.1
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --component-tag is missing"
      When run common/lib/scripts/tag-collection --image postgres --collection-version sbomify-v0.27.0-20260329.1
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --collection-version is missing"
      When run common/lib/scripts/tag-collection --image postgres --component-tag postgres-16.8-abc1234
      The status should be failure
      The output should include "Usage"
    End

    It "fails for unknown option"
      When run common/lib/scripts/tag-collection --unknown value
      The status should be failure
      The output should include "Unknown option"
    End
  End

  Describe "crane integration"
    setup() {
      MOCK_BIN="$(mktemp -d)"

      cat > "${MOCK_BIN}/crane" <<'SCRIPT'
#!/bin/sh
if [ "$1" = "digest" ]; then
  echo "sha256:abcdef1234567890"
  exit 0
elif [ "$1" = "tag" ]; then
  echo "CRANE_TAG $2 $3" >&2
  exit 0
fi
exit 1
SCRIPT
      chmod +x "${MOCK_BIN}/crane"
    }

    cleanup() {
      rm -rf "$MOCK_BIN"
    }
    Before "setup"
    After "cleanup"

    It "resolves the digest by component tag"
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/tag-collection --image postgres --component-tag postgres-16.8-abc1234 --collection-version sbomify-v0.27.0-20260329.1' _ "$MOCK_BIN"
      The status should be success
      The output should include "postgres-16.8-abc1234"
      The output should include "sha256:abcdef1234567890"
    End

    It "adds the collection version tag"
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/tag-collection --image postgres --component-tag postgres-16.8-abc1234 --collection-version sbomify-v0.27.0-20260329.1' _ "$MOCK_BIN"
      The status should be success
      The output should include "sbomify-v0.27.0-20260329.1"
    End

    It "prints completion message"
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/tag-collection --image postgres --component-tag postgres-16.8-abc1234 --collection-version sbomify-v0.27.0-20260329.1' _ "$MOCK_BIN"
      The status should be success
      The output should include "Tagged postgres"
    End

    It "supports custom registry via --registry"
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/tag-collection --image postgres --component-tag postgres-16.8-abc1234 --collection-version sbomify-v0.27.0-20260329.1 --registry ghcr.io/custom/repo' _ "$MOCK_BIN"
      The status should be success
      The output should include "ghcr.io/custom/repo/postgres"
    End

    It "supports custom registry via REGISTRY env var"
      When run sh -c 'PATH="$1:$PATH" REGISTRY=ghcr.io/env/repo common/lib/scripts/tag-collection --image redis --component-tag redis-8.0.2-def5678 --collection-version sbomify-v0.27.0-20260329.1' _ "$MOCK_BIN"
      The status should be success
      The output should include "ghcr.io/env/repo/redis"
    End
  End

  Describe "crane failure handling"
    setup_failing_crane() {
      MOCK_BIN="$(mktemp -d)"
      cat > "${MOCK_BIN}/crane" <<'SCRIPT'
#!/bin/sh
echo "NOT_FOUND" >&2
exit 1
SCRIPT
      chmod +x "${MOCK_BIN}/crane"
    }

    cleanup_failing_crane() {
      rm -rf "$MOCK_BIN"
    }
    Before "setup_failing_crane"
    After "cleanup_failing_crane"

    It "fails when crane cannot resolve the component tag"
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/tag-collection --image postgres --component-tag postgres-16.8-missing --collection-version sbomify-v0.27.0-20260329.1' _ "$MOCK_BIN"
      The status should be failure
      The output should include "Component tag"
      The output should include "not found"
    End
  End
End
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `shellspec common/lib/tests/tag_collection_spec.sh`
Expected: All tests FAIL (script doesn't exist yet)

- [ ] **Step 3: Write the `tag-collection` script**

Create `common/lib/scripts/tag-collection`:

```bash
#!/usr/bin/env bash
# common/lib/scripts/tag-collection — Add a collection version tag to an image found by component tag.
#
# Usage:
#   common/lib/scripts/tag-collection \
#     --image <name> \
#     --component-tag <tag> \
#     --collection-version <version>
#
# Requires: crane

set -euo pipefail

usage() {
  echo "Usage: $0 --image NAME --component-tag TAG --collection-version VERSION [--registry REGISTRY]"
  exit 1
}

IMAGE=""
COMPONENT_TAG=""
COLLECTION_VERSION=""
REGISTRY="${REGISTRY:-ghcr.io/wellmaintained/packages}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2 ;;
    --component-tag) COMPONENT_TAG="$2"; shift 2 ;;
    --collection-version) COLLECTION_VERSION="$2"; shift 2 ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

[[ -z "$IMAGE" || -z "$COMPONENT_TAG" || -z "$COLLECTION_VERSION" ]] && usage

REPO="${REGISTRY}/${IMAGE}"

echo "==> Resolving ${REPO}:${COMPONENT_TAG}"

DIGEST=$(crane digest "${REPO}:${COMPONENT_TAG}" 2>&1) || {
  echo "ERROR: crane digest failed with: ${DIGEST}"
  echo "Component tag '${COMPONENT_TAG}' not found for ${REPO}."
  exit 1
}

echo "    Digest: ${DIGEST}"
echo "    Adding collection tag: ${COLLECTION_VERSION}"

crane tag "${REPO}@${DIGEST}" "${COLLECTION_VERSION}"

echo "==> Tagged ${IMAGE} with ${COLLECTION_VERSION}"
```

- [ ] **Step 4: Make script executable**

Run: `chmod +x common/lib/scripts/tag-collection`

- [ ] **Step 5: Run tests to verify they pass**

Run: `shellspec common/lib/tests/tag_collection_spec.sh`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add common/lib/scripts/tag-collection common/lib/tests/tag_collection_spec.sh
git commit -m "feat: add tag-collection script for collection tagging (ADR-0005)"
```

---

### Task 2: Update `extract-sbom-attestation` to use component tags

The script currently finds images by `pr-{PR}-{SHA}` tag. Update it to accept `--tag` (the component tag) instead, while keeping `--image` for the repo path.

**Files:**
- Modify: `common/lib/scripts/extract-sbom-attestation`
- Modify: `common/lib/tests/extract_sbom_attestation_spec.sh`

- [ ] **Step 1: Update tests to use `--tag` interface**

Replace the `--pr`/`--sha` parameters with `--tag` in `common/lib/tests/extract_sbom_attestation_spec.sh`:

The new argument validation section:

```sh
# shellcheck shell=sh
Describe "common/lib/scripts/extract-sbom-attestation"

  Describe "argument validation"
    It "fails when no arguments given"
      When run common/lib/scripts/extract-sbom-attestation
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --image is missing"
      When run common/lib/scripts/extract-sbom-attestation --tag postgres-16.8-abc1234 --output sbom/test.json
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --tag is missing"
      When run common/lib/scripts/extract-sbom-attestation --image postgres --output sbom/test.json
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --output is missing"
      When run common/lib/scripts/extract-sbom-attestation --image postgres --tag postgres-16.8-abc1234
      The status should be failure
      The output should include "Usage"
    End

    It "fails for unknown option"
      When run common/lib/scripts/extract-sbom-attestation --unknown value
      The status should be failure
      The output should include "Unknown option"
    End
  End

  Describe "SBOM extraction"
    SAMPLE_SBOM='{"bomFormat":"CycloneDX","specVersion":"1.5","components":[]}'

    setup() {
      MOCK_BIN="$(mktemp -d)"
      OUTPUT_DIR="$(mktemp -d)"

      INTOTO_STATEMENT=$(printf '{"predicateType":"https://cyclonedx.org/bom","predicate":%s}' "$SAMPLE_SBOM")
      ENCODED_PAYLOAD=$(printf '%s' "$INTOTO_STATEMENT" | base64 -w0)
      DSSE_ENVELOPE=$(printf '{"payloadType":"application/vnd.in-toto+json","payload":"%s","signatures":[]}' "$ENCODED_PAYLOAD")

      cat > "${MOCK_BIN}/crane" <<'SCRIPT'
#!/bin/sh
if [ "$1" = "digest" ]; then
  echo "sha256:abcdef1234567890"
  exit 0
fi
exit 1
SCRIPT
      chmod +x "${MOCK_BIN}/crane"

      cat > "${MOCK_BIN}/cosign" <<SCRIPT
#!/bin/sh
if [ "\$1" = "download" ] && [ "\$2" = "attestation" ]; then
  echo '${DSSE_ENVELOPE}'
  exit 0
fi
exit 1
SCRIPT
      chmod +x "${MOCK_BIN}/cosign"
    }

    cleanup() {
      rm -rf "$MOCK_BIN" "$OUTPUT_DIR"
    }
    Before "setup"
    After "cleanup"

    It "extracts the SBOM to the output path"
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/extract-sbom-attestation --image postgres --tag postgres-16.8-abc1234 --output "$2/sbom/postgres.enriched.cdx.json"' _ "$MOCK_BIN" "$OUTPUT_DIR"
      The status should be success
      The stderr should include "Extracting SBOM attestation"
      The stderr should include "SBOM extracted"
    End

    It "creates the output directory if it does not exist"
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/extract-sbom-attestation --image postgres --tag postgres-16.8-abc1234 --output "$2/nested/dir/sbom.json"' _ "$MOCK_BIN" "$OUTPUT_DIR"
      The status should be success
      The stderr should include "SBOM extracted"
    End

    It "writes valid CycloneDX JSON"
      extract_sbom() {
        PATH="${MOCK_BIN}:$PATH" common/lib/scripts/extract-sbom-attestation \
          --image postgres --tag postgres-16.8-abc1234 \
          --output "${OUTPUT_DIR}/sbom.json" 2>/dev/null
        jq -r '.bomFormat' "${OUTPUT_DIR}/sbom.json"
      }
      When call extract_sbom
      The output should equal "CycloneDX"
    End

    It "resolves the component tag correctly"
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/extract-sbom-attestation --image postgres --tag postgres-16.8-abc1234 --output "$2/sbom.json"' _ "$MOCK_BIN" "$OUTPUT_DIR"
      The stderr should include "postgres-16.8-abc1234"
    End

    It "supports custom registry via --registry"
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/extract-sbom-attestation --image postgres --tag postgres-16.8-abc1234 --output "$2/sbom.json" --registry ghcr.io/custom/repo' _ "$MOCK_BIN" "$OUTPUT_DIR"
      The status should be success
      The stderr should include "ghcr.io/custom/repo/postgres"
    End

    It "supports custom registry via REGISTRY env var"
      When run sh -c 'PATH="$1:$PATH" REGISTRY=ghcr.io/env/repo common/lib/scripts/extract-sbom-attestation --image redis --tag redis-8.0.2-def5678 --output "$2/sbom.json"' _ "$MOCK_BIN" "$OUTPUT_DIR"
      The status should be success
      The stderr should include "ghcr.io/env/repo/redis"
    End
  End

  Describe "crane failure handling"
    setup_failing_crane() {
      MOCK_BIN="$(mktemp -d)"
      OUTPUT_DIR="$(mktemp -d)"
      cat > "${MOCK_BIN}/crane" <<'SCRIPT'
#!/bin/sh
echo "NOT_FOUND" >&2
exit 1
SCRIPT
      chmod +x "${MOCK_BIN}/crane"

      cat > "${MOCK_BIN}/cosign" <<'SCRIPT'
#!/bin/sh
exit 1
SCRIPT
      chmod +x "${MOCK_BIN}/cosign"
    }

    cleanup_failing_crane() {
      rm -rf "$MOCK_BIN" "$OUTPUT_DIR"
    }
    Before "setup_failing_crane"
    After "cleanup_failing_crane"

    It "fails when crane cannot resolve the component tag"
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/extract-sbom-attestation --image postgres --tag postgres-16.8-missing --output "$2/sbom.json"' _ "$MOCK_BIN" "$OUTPUT_DIR"
      The status should be failure
      The stderr should include "Component tag"
      The stderr should include "not found"
    End
  End

  Describe "cosign failure handling"
    setup_failing_cosign() {
      MOCK_BIN="$(mktemp -d)"
      OUTPUT_DIR="$(mktemp -d)"

      cat > "${MOCK_BIN}/crane" <<'SCRIPT'
#!/bin/sh
if [ "$1" = "digest" ]; then echo "sha256:abc"; exit 0; fi
exit 1
SCRIPT
      chmod +x "${MOCK_BIN}/crane"

      cat > "${MOCK_BIN}/cosign" <<'SCRIPT'
#!/bin/sh
echo "no attestation found" >&2
exit 1
SCRIPT
      chmod +x "${MOCK_BIN}/cosign"
    }

    cleanup_failing_cosign() {
      rm -rf "$MOCK_BIN" "$OUTPUT_DIR"
    }
    Before "setup_failing_cosign"
    After "cleanup_failing_cosign"

    It "fails when cosign cannot download attestation"
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/extract-sbom-attestation --image postgres --tag postgres-16.8-abc1234 --output "$2/sbom.json"' _ "$MOCK_BIN" "$OUTPUT_DIR"
      The status should be failure
      The stderr should include "Extracting SBOM attestation"
    End
  End
End
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `shellspec common/lib/tests/extract_sbom_attestation_spec.sh`
Expected: FAIL (script still expects `--pr`/`--sha`)

- [ ] **Step 3: Update the `extract-sbom-attestation` script**

Replace the full script at `common/lib/scripts/extract-sbom-attestation`:

```bash
#!/usr/bin/env bash
# common/lib/scripts/extract-sbom-attestation — Extract CycloneDX SBOM from OCI attestation.
#
# Usage:
#   common/lib/scripts/extract-sbom-attestation \
#     --image <name> \
#     --tag <component-tag> \
#     --output <path>
#
# Requires: crane, cosign, jq, base64

set -euo pipefail

usage() {
  echo "Usage: $0 --image NAME --tag COMPONENT_TAG --output PATH [--registry REGISTRY]"
  exit 1
}

IMAGE=""
TAG=""
OUTPUT=""
REGISTRY="${REGISTRY:-ghcr.io/wellmaintained/packages}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

[[ -z "$IMAGE" || -z "$TAG" || -z "$OUTPUT" ]] && usage

REPO="${REGISTRY}/${IMAGE}"

echo "==> Resolving digest for ${REPO}:${TAG}" >&2

DIGEST=$(crane digest "${REPO}:${TAG}" 2>&1) || {
  echo "ERROR: crane digest failed with: ${DIGEST}" >&2
  echo "Component tag '${TAG}' not found for ${REPO}." >&2
  exit 1
}

IMAGE_REF="${REPO}@${DIGEST}"
echo "==> Extracting SBOM attestation from ${IMAGE_REF}" >&2

OUTPUT_DIR=$(dirname "$OUTPUT")
mkdir -p "$OUTPUT_DIR"

cosign download attestation \
  --predicate-type https://cyclonedx.org/bom \
  "${IMAGE_REF}" \
  | jq -r '.payload' | base64 -d | jq '.predicate' \
  > "$OUTPUT"

echo "==> SBOM extracted to ${OUTPUT}" >&2
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `shellspec common/lib/tests/extract_sbom_attestation_spec.sh`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add common/lib/scripts/extract-sbom-attestation common/lib/tests/extract_sbom_attestation_spec.sh
git commit -m "refactor: update extract-sbom-attestation to use component tags (ADR-0005)"
```

---

### Task 3: Delete old promote-image script and tests

**Files:**
- Delete: `common/lib/scripts/promote-image`
- Delete: `common/lib/tests/promote_image_spec.sh`

- [ ] **Step 1: Delete the files**

```bash
git rm common/lib/scripts/promote-image common/lib/tests/promote_image_spec.sh
```

- [ ] **Step 2: Run all shellspec tests to confirm nothing breaks**

Run: `shellspec`
Expected: All tests PASS (no remaining references to promote-image)

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: remove promote-image script (replaced by tag-collection)"
```

---

## Chunk 2: Workflow

### Task 4: Create `.github/workflows/pre-release.yml`

This is the main workflow that replaces `promote.yml`. It runs on merge to main and:
1. Resolves the PR that was merged (same pattern as promote.yml)
2. Gets the sbomify-app version for the collection version
3. Computes the build number from existing git tags
4. Tags all 7 images with the collection version
5. Extracts SBOMs and uploads to sbomify
6. Creates a git tag and GitHub pre-release

**Files:**
- Create: `.github/workflows/pre-release.yml`

- [ ] **Step 1: Create the workflow file**

Create `.github/workflows/pre-release.yml`:

```yaml
name: Pre-release collection

# On merge to main, create a collection pre-release (ADR-0005).
# Adds collection version tag to all images, creates GitHub pre-release.

on:
  push:
    branches: [main]
    paths:
      - common/**
      - apps/**
      - flake.nix
      - flake.lock
  workflow_dispatch:
    inputs:
      pr_number:
        description: 'PR number to release (required for manual trigger)'
        required: false
      head_sha7:
        description: 'First 7 chars of PR head SHA (required for manual trigger)'
        required: false

permissions:
  actions: read
  contents: write
  packages: write

env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true

jobs:
  load-matrix:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set.outputs.matrix }}
    steps:
      - uses: actions/checkout@v5
      - id: set
        run: echo "matrix=$(jq -c . .github/image-matrix.json)" >> "$GITHUB_OUTPUT"

  resolve-pr:
    runs-on: blacksmith-2vcpu-ubuntu-2404
    outputs:
      pr_number: ${{ steps.pr.outputs.pr_number }}
      head_sha7: ${{ steps.pr.outputs.head_sha7 }}
      skip: ${{ steps.pr.outputs.skip }}
    steps:
      - name: Resolve PR from merge commit
        id: pr
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          # Use workflow_dispatch inputs if provided
          if [ -n "${{ inputs.pr_number }}" ] && [ -n "${{ inputs.head_sha7 }}" ]; then
            echo "Using manual inputs: PR=${{ inputs.pr_number }}, SHA=${{ inputs.head_sha7 }}"
            echo "pr_number=${{ inputs.pr_number }}" >> "$GITHUB_OUTPUT"
            echo "head_sha7=${{ inputs.head_sha7 }}" >> "$GITHUB_OUTPUT"
            echo "skip=false" >> "$GITHUB_OUTPUT"
            exit 0
          fi

          # Find the PR that was merged to produce this push
          PR_NUMBER=$(gh api \
            "repos/${{ github.repository }}/commits/${{ github.sha }}/pulls" \
            --jq '.[0].number' 2>/dev/null || true)

          if [ -z "$PR_NUMBER" ] || [ "$PR_NUMBER" = "null" ]; then
            echo "WARNING: Could not resolve PR for commit ${{ github.sha }}"
            echo "skip=true" >> "$GITHUB_OUTPUT"
            exit 0
          fi

          HEAD_SHA=$(gh pr view "$PR_NUMBER" \
            --repo "${{ github.repository }}" \
            --json headRefOid --jq '.headRefOid')
          SHA7="${HEAD_SHA::7}"

          echo "pr_number=${PR_NUMBER}" >> "$GITHUB_OUTPUT"
          echo "head_sha7=${SHA7}" >> "$GITHUB_OUTPUT"
          echo "skip=false" >> "$GITHUB_OUTPUT"

  resolve-version:
    needs: [resolve-pr]
    if: needs.resolve-pr.outputs.skip != 'true'
    runs-on: blacksmith-2vcpu-ubuntu-2404
    defaults:
      run:
        shell: nix develop .#ci -c bash -e {0}
    outputs:
      collection_version: ${{ steps.version.outputs.collection_version }}
      app_version: ${{ steps.version.outputs.app_version }}
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0
          fetch-tags: true

      - name: Setup Nix
        uses: ./.github/actions/setup-nix

      - name: Compute collection version
        id: version
        run: |
          # Get app version from sbomify-app image metadata
          META=$(common/lib/scripts/build-and-push metadata --package sbomify-app-image)
          APP_VERSION=$(echo "$META" | jq -r .version)
          echo "app_version=${APP_VERSION}" >> "$GITHUB_OUTPUT"

          # Compute build number: count existing tags for today + 1
          TODAY=$(date -u '+%Y%m%d')
          PREFIX="sbomify-v${APP_VERSION}-${TODAY}."
          EXISTING=$(git tag -l "${PREFIX}*" | wc -l)
          BUILD_NUMBER=$((EXISTING + 1))

          COLLECTION_VERSION="sbomify-v${APP_VERSION}-${TODAY}.${BUILD_NUMBER}"
          echo "collection_version=${COLLECTION_VERSION}" >> "$GITHUB_OUTPUT"
          echo "==> Collection version: ${COLLECTION_VERSION}"

  tag-collection:
    needs: [load-matrix, resolve-pr, resolve-version]
    if: needs.resolve-pr.outputs.skip != 'true'
    runs-on: blacksmith-2vcpu-ubuntu-2404
    defaults:
      run:
        shell: nix develop .#ci -c bash -e {0}
    strategy:
      fail-fast: false
      matrix:
        image: ${{ fromJson(needs.load-matrix.outputs.matrix) }}
    outputs:
      # Collect digests for release notes (via matrix outputs workaround)
      digest: ${{ steps.tag.outputs.digest }}
    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Setup Nix
        uses: ./.github/actions/setup-nix
        with:
          stickydisk-suffix: ${{ matrix.image.name }}

      - name: Log in to GHCR
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Get upstream version
        id: meta
        run: |
          META=$(common/lib/scripts/build-and-push metadata --package "${{ matrix.image.package }}")
          echo "version=$(echo "$META" | jq -r .version)" >> "$GITHUB_OUTPUT"
          echo "sbomify_component_id=$(echo "$META" | jq -r .sbomifyComponentId)" >> "$GITHUB_OUTPUT"
          echo "name=$(echo "$META" | jq -r .name)" >> "$GITHUB_OUTPUT"

      - name: Compute component tag
        id: component
        run: |
          SHA7="${{ needs.resolve-pr.outputs.head_sha7 }}"
          NAME="${{ steps.meta.outputs.name }}"
          VERSION="${{ steps.meta.outputs.version }}"
          echo "tag=${NAME}-${VERSION}-${SHA7}" >> "$GITHUB_OUTPUT"

      - name: Add collection tag
        id: tag
        run: |
          common/lib/scripts/tag-collection \
            --image "${{ matrix.image.name }}" \
            --component-tag "${{ steps.component.outputs.tag }}" \
            --collection-version "${{ needs.resolve-version.outputs.collection_version }}"

          # Output digest for release notes
          REPO="ghcr.io/wellmaintained/packages/${{ matrix.image.name }}"
          DIGEST=$(crane digest "${REPO}:${{ steps.component.outputs.tag }}")
          echo "digest=${DIGEST}" >> "$GITHUB_OUTPUT"

      - name: Extract SBOM from OCI attestation
        continue-on-error: true
        run: |
          common/lib/scripts/extract-sbom-attestation \
            --image "${{ matrix.image.name }}" \
            --tag "${{ steps.component.outputs.tag }}" \
            --output "sbom/${{ steps.meta.outputs.name }}.enriched.cdx.json"

      - name: Upload SBOM to sbomify.com
        if: ${{ !startsWith(steps.meta.outputs.sbomify_component_id, 'PLACEHOLDER') }}
        uses: sbomify/sbomify-action@d96675bf9fcbeba415e618895af758a6216395d0 # v26.1.0
        continue-on-error: true
        env:
          TOKEN: ${{ secrets.SBOMIFY_TOKEN }}
          COMPONENT_ID: ${{ steps.meta.outputs.sbomify_component_id }}
          SBOM_FILE: sbom/${{ steps.meta.outputs.name }}.enriched.cdx.json
          SBOM_FORMAT: cyclonedx
          UPLOAD: true

  create-release:
    needs: [resolve-pr, resolve-version, tag-collection, load-matrix]
    if: needs.resolve-pr.outputs.skip != 'true'
    runs-on: blacksmith-2vcpu-ubuntu-2404
    defaults:
      run:
        shell: nix develop .#ci -c bash -e {0}
    steps:
      - name: Checkout
        uses: actions/checkout@v5
        with:
          fetch-depth: 0
          fetch-tags: true

      - name: Setup Nix
        uses: ./.github/actions/setup-nix

      - name: Log in to GHCR
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build release notes
        id: notes
        run: |
          COLLECTION_VERSION="${{ needs.resolve-version.outputs.collection_version }}"
          REGISTRY="ghcr.io/wellmaintained/packages"
          SHA7="${{ needs.resolve-pr.outputs.head_sha7 }}"

          NOTES="## Collection: ${COLLECTION_VERSION}\n\n"
          NOTES+="**Source PR:** #${{ needs.resolve-pr.outputs.pr_number }}\n"
          NOTES+="**App version:** ${{ needs.resolve-version.outputs.app_version }}\n\n"
          NOTES+="### Images\n\n"
          NOTES+="| Image | Component Tag | Digest |\n"
          NOTES+="|-------|--------------|--------|\n"

          # Read matrix and resolve each image
          MATRIX='${{ needs.load-matrix.outputs.matrix }}'
          for ROW in $(echo "$MATRIX" | jq -c '.[]'); do
            NAME=$(echo "$ROW" | jq -r .name)
            PKG=$(echo "$ROW" | jq -r .package)

            META=$(common/lib/scripts/build-and-push metadata --package "$PKG")
            IMG_NAME=$(echo "$META" | jq -r .name)
            VERSION=$(echo "$META" | jq -r .version)
            COMPONENT_TAG="${IMG_NAME}-${VERSION}-${SHA7}"

            DIGEST=$(crane digest "${REGISTRY}/${NAME}:${COMPONENT_TAG}" 2>/dev/null || echo "unknown")
            SHORT_DIGEST="${DIGEST::19}"

            NOTES+="| \`${NAME}\` | \`${COMPONENT_TAG}\` | \`${SHORT_DIGEST}\` |\n"
          done

          # Write notes to file (avoids quoting issues in gh release)
          printf "%b" "$NOTES" > release-notes.md
          cat release-notes.md

      - name: Create git tag and GitHub pre-release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          COLLECTION_VERSION="${{ needs.resolve-version.outputs.collection_version }}"

          git tag "${COLLECTION_VERSION}"
          git push origin "${COLLECTION_VERSION}"

          gh release create "${COLLECTION_VERSION}" \
            --title "${COLLECTION_VERSION}" \
            --notes-file release-notes.md \
            --prerelease
```

- [ ] **Step 2: Validate YAML syntax**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pre-release.yml'))"`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/pre-release.yml
git commit -m "feat: add pre-release workflow for collection releases (ADR-0005)"
```

---

### Task 5: Delete `promote.yml`

**Files:**
- Delete: `.github/workflows/promote.yml`

- [ ] **Step 1: Delete promote.yml**

```bash
git rm .github/workflows/promote.yml
```

- [ ] **Step 2: Verify no remaining references to promote.yml**

Run: `grep -r "promote.yml\|promote-image" .github/ common/lib/`
Expected: No matches (other than this plan file or ADR references)

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: remove promote.yml (replaced by pre-release.yml, ADR-0005)"
```

---

## Verification

After all tasks are complete:

- [ ] **Run all shellspec tests**: `shellspec`
  - Expected: All tests pass, no references to promote-image or pr-{PR}-{SHA} in test output

- [ ] **Validate all workflow YAML**: `python3 -c "import yaml; [yaml.safe_load(open(f)) for f in __import__('glob').glob('.github/workflows/*.yml')]"`

- [ ] **Verify file state**:
  - `ls common/lib/scripts/tag-collection` exists and is executable
  - `ls common/lib/scripts/promote-image` does NOT exist
  - `ls .github/workflows/pre-release.yml` exists
  - `ls .github/workflows/promote.yml` does NOT exist
  - `ls common/lib/tests/tag_collection_spec.sh` exists
  - `ls common/lib/tests/promote_image_spec.sh` does NOT exist
