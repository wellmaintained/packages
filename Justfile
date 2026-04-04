# Justfile — local development tasks for wellmaintained/packages

set dotenv-load

# Show available targets
default:
  @just --list

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
  BUILD_DIR="${REPO_ROOT}/.local/build"
  SBOM_DIR="${BUILD_DIR}/sboms"
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
    nix build ".#${package}" --out-link "${BUILD_DIR}/result-image"

    # Get metadata
    meta=$(nix eval --json ".#${package}.imageMetadata")
    version=$(echo "$meta" | jq -r .version)
    component_id=$(just _image-component-id "$name")

    # Build SBOM
    echo "==> Building SBOM"
    nix build ".#${package}.patchedSbom" --out-link "${BUILD_DIR}/result-sbom"
    cp -L --no-preserve=mode "${BUILD_DIR}/result-sbom" "${SBOM_DIR}/${name}.cdx.json"
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

  # Clean up nix result symlinks
  rm -f "${BUILD_DIR}/result-image" "${BUILD_DIR}/result-sbom"

  echo ""
  echo "SBOMs written to: ${SBOM_DIR}/"

# Score an SBOM using sbomqs — human-readable summary.
#
# Usage:
#   just score-sbom postgres
score-sbom name:
  #!/usr/bin/env bash
  set -euo pipefail

  sbom=".local/build/sboms/{{name}}.cdx.json"
  if [[ ! -f "$sbom" ]]; then
    echo "ERROR: SBOM not found: $sbom" >&2
    echo "Run 'just build-image {{name}}' first." >&2
    exit 1
  fi

  if ! command -v sbomqs &>/dev/null; then
    echo "ERROR: sbomqs not found. Run 'direnv allow' to load the devShell." >&2
    exit 1
  fi

  json_out=".local/build/sboms/{{name}}.score.json"
  common/lib/scripts/sbom-score --image "{{name}}" --format text --json-output "$json_out" "$sbom"
  echo ""
  echo "Score JSON: ${json_out}"

# Scan an SBOM for vulnerabilities using grype — human-readable summary.
#
# Usage:
#   just scan-sbom postgres
scan-sbom name:
  #!/usr/bin/env bash
  set -euo pipefail

  sbom=".local/build/sboms/{{name}}.cdx.json"
  if [[ ! -f "$sbom" ]]; then
    echo "ERROR: SBOM not found: $sbom" >&2
    echo "Run 'just build-image {{name}}' first." >&2
    exit 1
  fi

  if ! command -v grype &>/dev/null; then
    echo "ERROR: grype not found. Run 'direnv allow' to load the devShell." >&2
    exit 1
  fi

  json_out=".local/build/sboms/{{name}}.scan.json"
  table_out=".local/build/sboms/{{name}}.scan.table"

  # Resolve per-image VEX file (same logic as CI workflows)
  vex_flag=""
  for candidate in "common/images/{{name}}.vex.yaml" "apps/sbomify/images/{{name}}.vex.yaml"; do
    if [[ -f "$candidate" ]]; then
      vex_json=$(mktemp --suffix=.vex.json)
      trap "rm -f '$vex_json'" EXIT
      yq -o json "$candidate" > "$vex_json"
      vex_flag="--vex ${vex_json}"
      echo "==> Using VEX suppression from ${candidate}" >&2
      break
    fi
  done

  # Single grype pass: save JSON for CI, table for display
  grype "sbom:${sbom}" -o "json=${json_out}" -o "table=${table_out}" --by-cve --sort-by severity $vex_flag

  echo ""
  echo "=== Vulnerability Scan: {{name}} ==="
  echo ""

  match_count=$(jq '.matches | length' "$json_out" 2>/dev/null || echo "0")
  if [[ "$match_count" == "0" ]]; then
    echo "No vulnerabilities found."
    exit 0
  fi

  echo "Summary:"
  jq -r '
    [.matches[].vulnerability.severity] |
    map(if . == "" then "Unknown" else . end) |
    group_by(.) | map({severity: .[0], count: length}) |
    sort_by(
      if   .severity == "Critical"   then 0
      elif .severity == "High"       then 1
      elif .severity == "Medium"     then 2
      elif .severity == "Low"        then 3
      elif .severity == "Negligible" then 4
      else                                5
      end
    )[] |
    "  \(.severity): \(.count)"
  ' "$json_out"
  echo "  Total: ${match_count}"
  echo ""
  cat "$table_out"
  rm -f "$table_out"
  echo ""
  echo "Scan results: ${json_out}"

# Compare local SBOM against the latest released version.
# Fetches the baseline from the OCI attestation in GHCR.
#
# Requires: crane auth login ghcr.io (one-time setup)
#
# Usage:
#   just compare-sbom postgres
compare-sbom name:
  #!/usr/bin/env bash
  set -euo pipefail

  current=".local/build/sboms/{{name}}.cdx.json"
  if [[ ! -f "$current" ]]; then
    echo "ERROR: SBOM not found: $current" >&2
    echo "Run 'just build-image {{name}}' first." >&2
    exit 1
  fi

  for cmd in crane sbomlyze; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "ERROR: ${cmd} not found. Run 'direnv allow' to load the devShell." >&2
      exit 1
    fi
  done

  REGISTRY="ghcr.io/wellmaintained/packages"

  # Find the latest released tag
  echo "==> Finding latest release tag for {{name}}…"
  BASELINE_TAG=$(crane ls "${REGISTRY}/{{name}}" 2>/dev/null \
    | grep -E "^{{name}}-" \
    | tail -1) || true

  if [[ -z "$BASELINE_TAG" ]]; then
    echo "No released baseline found for {{name}} in ${REGISTRY}." >&2
    echo "Hint: run 'crane auth login ghcr.io' if you haven't authenticated." >&2
    exit 1
  fi

  echo "==> Baseline: ${BASELINE_TAG}"

  # Extract baseline SBOM from OCI attestation
  baseline_dir=".local/build/sboms/baselines"
  mkdir -p "$baseline_dir"
  baseline="${baseline_dir}/{{name}}.cdx.json"

  common/lib/scripts/extract-sbom-attestation \
    --image "{{name}}" \
    --tag "$BASELINE_TAG" \
    --output "$baseline"

  # Compare
  raw=$(common/lib/scripts/sbom-compare \
    --baseline "$baseline" \
    --current "$current" \
    --image "{{name}}" \
    --policy .github/sbom-policy.json)

  echo ""
  echo "=== SBOM Comparison: {{name}} ==="
  echo "  Local:    ${current}"
  echo "  Baseline: ${BASELINE_TAG}"
  echo ""
  echo "$raw" | jq -r '.diff_md'
  echo ""
  policy_ok=$(echo "$raw" | jq -r '.policy_pass')
  if [[ "$policy_ok" == "true" ]]; then
    echo "Policy: PASS"
  else
    echo "Policy: FAIL"
  fi
