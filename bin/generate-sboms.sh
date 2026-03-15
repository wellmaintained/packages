#!/usr/bin/env bash
set -euo pipefail

# Generate CycloneDX SBOMs for all Nix-built OCI images using bombon.
# Each SBOM is built via `nix build .#<name>-sbom` and copied to sboms/<name>.cdx.json.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SBOM_DIR="${REPO_ROOT}/sboms"

# All image SBOM targets (must match flake.nix packages)
# Format: name:license (SPDX identifier)
SBOM_TARGETS=(
  postgres:PostgreSQL
  redis:AGPL-3.0-only
  minio:AGPL-3.0-or-later
  minio-client:Apache-2.0
  sbomify-app:Apache-2.0
  sbomify-keycloak:Apache-2.0
  sbomify-caddy-dev:Apache-2.0
  sbomify-minio-init:Apache-2.0
)

mkdir -p "$SBOM_DIR"

echo "Generating SBOMs for ${#SBOM_TARGETS[@]} images..."
echo ""

failed=()

for entry in "${SBOM_TARGETS[@]}"; do
  target="${entry%%:*}"
  license="${entry#*:}"
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

    # Patch root component: bombon uses the symlinkJoin name (e.g. "postgres-closure")
    # which is meaningless. Rewrite it to describe the OCI image with proper metadata
    # and wire up the dependency graph.
    version=$(nix eval --raw nixpkgs#"${target//-/_}".version 2>/dev/null || echo "unknown")
    image_name="wellmaintained/packages/${target}-image"
    purl="pkg:docker/wellmaintained/packages/${target}@${version}"

    jq --arg name "$image_name" \
       --arg version "$version" \
       --arg purl "$purl" \
       --arg license "$license" \
       '
      .metadata.component.name = $name |
      .metadata.component.version = $version |
      .metadata.component.type = "container" |
      .metadata.component.purl = $purl |
      .metadata.component.licenses = [{"license": {"id": $license}}] |
      .metadata.component["bom-ref"] as $root |
      .dependencies = [
        {"ref": $root, "dependsOn": [.components[]?["bom-ref"]]}
      ] + [.dependencies[]? | select(.ref != $root)]
    ' "${SBOM_DIR}/${target}.cdx.json" > "${SBOM_DIR}/${target}.cdx.json.tmp" \
      && mv "${SBOM_DIR}/${target}.cdx.json.tmp" "${SBOM_DIR}/${target}.cdx.json"

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
