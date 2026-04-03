# Justfile — local development tasks for wellmaintained/packages

set dotenv-load

# Image matrix: name → nix package, sbomify component ID
# Keep in sync with .github/image-matrix.json
_image-package name:
  @jq -r --arg n "{{name}}" '.[] | select(.name == $n) | .package' .github/image-matrix.json

_image-component-id name:
  @jq -r --arg n "{{name}}" '.[] | select(.name == $n) | .sbomify_component_id' .github/image-matrix.json

_all-image-names:
  @jq -r '.[].name' .github/image-matrix.json

# Build a single OCI image + SBOM. Enriches via sbomify-action if SBOMIFY_TOKEN is set.
#
# Usage:
#   just build-image postgres
#   just build-image postgres --no-enrich
#   just build-image --all
build-image *args:
  #!/usr/bin/env bash
  set -euo pipefail

  no_enrich=false
  all=false
  names=()

  for arg in {{args}}; do
    case "$arg" in
      --no-enrich) no_enrich=true ;;
      --all)       all=true ;;
      *)           names+=("$arg") ;;
    esac
  done

  if $all; then
    mapfile -t names < <(just _all-image-names)
  fi

  if [[ ${#names[@]} -eq 0 ]]; then
    echo "Usage: just build-image <name> [--no-enrich]" >&2
    echo "       just build-image --all" >&2
    echo "" >&2
    echo "Available images:" >&2
    just _all-image-names | sed 's/^/  /' >&2
    exit 1
  fi

  REPO_ROOT="$(pwd)"
  SBOM_DIR="${REPO_ROOT}/sboms"
  mkdir -p "$SBOM_DIR"

  for name in "${names[@]}"; do
    package=$(just _image-package "$name")
    if [[ -z "$package" || "$package" == "null" ]]; then
      echo "ERROR: unknown image name '${name}'" >&2
      echo "Available:" >&2
      just _all-image-names | sed 's/^/  /' >&2
      exit 1
    fi

    echo ""
    echo "=== ${name} ==="

    # Build image
    echo "==> Building image: ${package}"
    nix build ".#${package}" --out-link result-image

    # Get metadata
    meta=$(nix eval --json ".#${package}.imageMetadata")
    version=$(echo "$meta" | jq -r .version)
    component_id=$(just _image-component-id "$name")

    # Build SBOM
    echo "==> Building SBOM"
    nix build ".#${package}.patchedSbom" --out-link result-sbom
    cp -L --no-preserve=mode result-sbom "${SBOM_DIR}/${name}.cdx.json"
    echo "  -> ${SBOM_DIR}/${name}.cdx.json"

    # Enrich (unless --no-enrich)
    if ! $no_enrich; then
      common/lib/scripts/enrich-sbom \
        --sbom-file "${SBOM_DIR}/${name}.cdx.json" \
        --sbomify-component-id "$component_id" \
        --name "$name" \
        --version "$version" \
        --output "${SBOM_DIR}/${name}.enriched.cdx.json"
    fi

    # Quick stats
    comp_count=$(jq '.components | length' "${SBOM_DIR}/${name}.cdx.json" 2>/dev/null || echo 0)
    echo "  Components: ${comp_count}"
  done

  # Clean up nix result symlink
  rm -f result-image result-sbom

  echo ""
  echo "SBOMs written to: ${SBOM_DIR}/"
