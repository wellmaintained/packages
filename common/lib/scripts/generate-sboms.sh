#!/usr/bin/env bash
set -euo pipefail

# Generate CycloneDX SBOMs for all Nix-built OCI images using nix-compliance-inator.
# Each SBOM is built via `nix build .#<name>-sbom` and copied to sboms/<name>.cdx.json.

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SBOM_DIR="${REPO_ROOT}/sboms"

# All image SBOM targets (must match flake.nix packages)
SBOM_TARGETS=(
  postgres
  redis
  minio
  sbomify-app
  sbomify-keycloak
  sbomify-caddy-dev
  sbomify-minio-init
)

mkdir -p "$SBOM_DIR"

echo "Generating SBOMs for ${#SBOM_TARGETS[@]} images..."
echo ""

failed=()

for target in "${SBOM_TARGETS[@]}"; do
  echo "--- ${target} ---"
  sbom_attr=".#${target}-sbom"

  if nix build "$sbom_attr" --out-link "${REPO_ROOT}/result-sbom-${target}" 2>&1; then
    # bombon output is a single .cdx.json file (the result symlink points directly to it)
    sbom_file="${REPO_ROOT}/result-sbom-${target}"

    if [ ! -e "$sbom_file" ]; then
      echo "  ERROR: nix build succeeded but output not found"
      failed+=("$target")
      continue
    fi

    cp -L "$sbom_file" "${SBOM_DIR}/${target}.cdx.json"
    echo "  -> ${SBOM_DIR}/${target}.cdx.json"

    # Quick verification
    bom_format=$(jq -r '.bomFormat // empty' "${SBOM_DIR}/${target}.cdx.json" 2>/dev/null || true)
    comp_count=$(jq '.components | length' "${SBOM_DIR}/${target}.cdx.json" 2>/dev/null || echo 0)
    has_licenses=$(jq '[.components[]? | select(.licenses != null and (.licenses | length > 0))] | length' "${SBOM_DIR}/${target}.cdx.json" 2>/dev/null || echo 0)

    if [ "$bom_format" != "CycloneDX" ]; then
      echo "  WARNING: bomFormat is '${bom_format}', expected 'CycloneDX'"
    fi

    echo "  Components: ${comp_count}"
    echo "  With licenses: ${has_licenses}"

    # Clean up result symlink
    rm -f "${REPO_ROOT}/result-sbom-${target}"
  else
    echo "  FAILED to build ${sbom_attr}"
    failed+=("$target")
  fi
  echo ""
done

echo "========================================"
echo "SBOMs written to: ${SBOM_DIR}/"
echo "Total: ${#SBOM_TARGETS[@]}, Failed: ${#failed[@]}"

if [ ${#failed[@]} -gt 0 ]; then
  echo ""
  echo "Failed targets:"
  for f in "${failed[@]}"; do
    echo "  - ${f}"
  done
  exit 1
fi

echo ""
echo "All SBOMs generated successfully."
