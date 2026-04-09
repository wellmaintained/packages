# shellcheck shell=sh
Describe "common/lib/scripts/extract-release-data"

  Describe "argument validation"
    It "fails when no arguments given"
      When run common/lib/scripts/extract-release-data
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --sbom-dir is missing"
      When run common/lib/scripts/extract-release-data \
        --scan-dir s --image-matrix m.json --output-dir out --tag t --version v --date d
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --scan-dir is missing"
      When run common/lib/scripts/extract-release-data \
        --sbom-dir s --image-matrix m.json --output-dir out --tag t --version v --date d
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --image-matrix is missing"
      When run common/lib/scripts/extract-release-data \
        --sbom-dir s --scan-dir s --output-dir out --tag t --version v --date d
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --output-dir is missing"
      When run common/lib/scripts/extract-release-data \
        --sbom-dir s --scan-dir s --image-matrix m.json --tag t --version v --date d
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --tag is missing"
      When run common/lib/scripts/extract-release-data \
        --sbom-dir s --scan-dir s --image-matrix m.json --output-dir out --version v --date d
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --version is missing"
      When run common/lib/scripts/extract-release-data \
        --sbom-dir s --scan-dir s --image-matrix m.json --output-dir out --tag t --date d
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --date is missing"
      When run common/lib/scripts/extract-release-data \
        --sbom-dir s --scan-dir s --image-matrix m.json --output-dir out --tag t --version v
      The status should be failure
      The output should include "Usage"
    End

    It "fails for unknown option"
      When run common/lib/scripts/extract-release-data --unknown value
      The status should be failure
      The output should include "Unknown option"
    End
  End

  Describe "missing SBOM detection"
    setup_missing() {
      WORK_DIR="$(mktemp -d)"
      SBOM_DIR="${WORK_DIR}/sboms"
      OUTPUT_DIR="${WORK_DIR}/output"
      mkdir -p "$SBOM_DIR" "$OUTPUT_DIR"

      echo '[{"name":"alpha"},{"name":"beta"}]' > "${WORK_DIR}/matrix.json"
      printf '{"metadata":{"component":{"version":"1.0"}},"components":[]}' > "${SBOM_DIR}/alpha.enriched.cdx.json"
    }

    cleanup_missing() {
      rm -rf "$WORK_DIR"
    }
    Before "setup_missing"
    After "cleanup_missing"

    It "fails with helpful error when an SBOM is missing"
      When run common/lib/scripts/extract-release-data \
        --sbom-dir "$SBOM_DIR" \
        --scan-dir "$SBOM_DIR" \
        --image-matrix "${WORK_DIR}/matrix.json" \
        --output-dir "$OUTPUT_DIR" \
        --tag test-tag --version 1.0 --date 2026-01-01
      The status should be failure
      The stderr should include "SBOM not found for beta"
      The stderr should include "just build-image"
    End
  End

  Describe "successful extraction"
    setup_extract() {
      WORK_DIR="$(mktemp -d)"
      SBOM_DIR="${WORK_DIR}/sboms"
      SCAN_DIR="${WORK_DIR}/scans"
      OUTPUT_DIR="${WORK_DIR}/output"
      mkdir -p "$SBOM_DIR" "$SCAN_DIR" "$OUTPUT_DIR"

      echo '[{"name":"postgres"},{"name":"redis"}]' > "${WORK_DIR}/matrix.json"

      printf '{"metadata":{"component":{"name":"wellmaintained/packages/postgres-image","version":"17.9"}},"components":[{"name":"openssl","version":"3.6.1","licenses":[{"license":{"id":"Apache-2.0"}}],"externalReferences":[{"type":"website","url":"https://openssl.org"}]}]}' \
        > "${SBOM_DIR}/postgres.enriched.cdx.json"
      printf '{"metadata":{"component":{"name":"wellmaintained/packages/redis-image","version":"8.2.3"}},"components":[{"name":"hiredis","version":"1.2.0","licenses":[{"license":{"id":"BSD-3-Clause"}}]}]}' \
        > "${SBOM_DIR}/redis.enriched.cdx.json"

      # Scan result for postgres only (redis has no scan)
      printf '{"matches":[{"vulnerability":{"id":"CVE-2025-0001","severity":"High","fix":{"versions":["3.6.2"],"state":""}},"artifact":{"name":"openssl","version":"3.6.1"}}]}' \
        > "${SCAN_DIR}/postgres.scan.json"
    }

    cleanup_extract() {
      rm -rf "$WORK_DIR"
    }
    Before "setup_extract"
    After "cleanup_extract"

    run_extract() {
      common/lib/scripts/extract-release-data \
        --sbom-dir "$SBOM_DIR" \
        --scan-dir "$SCAN_DIR" \
        --image-matrix "${WORK_DIR}/matrix.json" \
        --output-dir "$OUTPUT_DIR" \
        --tag "sbomify-v1.0-20260101.1" \
        --version "1.0" \
        --date "2026-01-01" 2>/dev/null
    }

    It "succeeds"
      When run common/lib/scripts/extract-release-data \
        --sbom-dir "$SBOM_DIR" \
        --scan-dir "$SCAN_DIR" \
        --image-matrix "${WORK_DIR}/matrix.json" \
        --output-dir "$OUTPUT_DIR" \
        --tag "sbomify-v1.0-20260101.1" \
        --version "1.0" \
        --date "2026-01-01"
      The status should be success
      The stderr should include "Wrote"
    End

    It "writes valid release.json"
      check_release_json() {
        run_extract
        jq -r '.tag' "${OUTPUT_DIR}/data/release.json"
      }
      When call check_release_json
      The output should equal "sbomify-v1.0-20260101.1"
    End

    It "includes all images in the array"
      check_image_count() {
        run_extract
        jq '.images | length' "${OUTPUT_DIR}/data/release.json"
      }
      When call check_image_count
      The output should equal "2"
    End

    It "extracts upstream_version from SBOM metadata"
      check_upstream_version() {
        run_extract
        jq -r '.images[] | select(.name == "postgres") | .upstream_version' "${OUTPUT_DIR}/data/release.json"
      }
      When call check_upstream_version
      The output should equal "17.9"
    End

    It "copies SBOMs to output artifacts directory"
      check_sbom_copy() {
        run_extract
        ls "${OUTPUT_DIR}/static/artifacts/sboms/" | sort | tr '\n' ' '
      }
      When call check_sbom_copy
      The output should equal "postgres.cdx.json redis.cdx.json "
    End

    It "writes vulnerabilities.json with findings from scanned images"
      check_vulns() {
        run_extract
        jq '.findings | length' "${OUTPUT_DIR}/data/vulnerabilities.json"
      }
      When call check_vulns
      The output should equal "1"
    End

    It "includes correct CVE data in findings"
      check_cve() {
        run_extract
        jq -r '.findings[0].cve' "${OUTPUT_DIR}/data/vulnerabilities.json"
      }
      When call check_cve
      The output should equal "CVE-2025-0001"
    End

    It "tracks scanned and missing images"
      check_scanned() {
        run_extract
        jq -r '.scanned_images | length' "${OUTPUT_DIR}/data/vulnerabilities.json"
      }
      When call check_scanned
      The output should equal "1"
    End

    It "reports missing scan images"
      check_missing() {
        run_extract
        jq -r '.missing_images[0]' "${OUTPUT_DIR}/data/vulnerabilities.json"
      }
      When call check_missing
      The output should equal "redis"
    End

    It "writes licenses.json with per-image components"
      check_licenses() {
        run_extract
        jq -r '.images.postgres[0].license' "${OUTPUT_DIR}/data/licenses.json"
      }
      When call check_licenses
      The output should equal "Apache-2.0"
    End

    It "includes license summary across all images"
      check_license_summary() {
        run_extract
        jq '.summary | length' "${OUTPUT_DIR}/data/licenses.json"
      }
      When call check_license_summary
      The output should equal "2"
    End

    It "includes website from SBOM external references"
      check_website() {
        run_extract
        jq -r '.images.postgres[0].website' "${OUTPUT_DIR}/data/licenses.json"
      }
      When call check_website
      The output should equal "https://openssl.org"
    End
  End
End
