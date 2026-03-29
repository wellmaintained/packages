# shellcheck shell=sh
Describe "common/lib/scripts/extract-sbom-attestation"

  Describe "argument validation"
    It "fails when no arguments given"
      When run common/lib/scripts/extract-sbom-attestation
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --image is missing"
      When run common/lib/scripts/extract-sbom-attestation --pr 42 --sha abc1234 --output sbom/test.json
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --pr is missing"
      When run common/lib/scripts/extract-sbom-attestation --image postgres --sha abc1234 --output sbom/test.json
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --sha is missing"
      When run common/lib/scripts/extract-sbom-attestation --image postgres --pr 42 --output sbom/test.json
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --output is missing"
      When run common/lib/scripts/extract-sbom-attestation --image postgres --pr 42 --sha abc1234
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
    # Build a realistic DSSE envelope with an embedded CycloneDX SBOM
    SAMPLE_SBOM='{"bomFormat":"CycloneDX","specVersion":"1.5","components":[]}'

    setup() {
      MOCK_BIN="$(mktemp -d)"
      OUTPUT_DIR="$(mktemp -d)"

      # Build the in-toto statement that cosign wraps in a DSSE envelope
      INTOTO_STATEMENT=$(printf '{"predicateType":"https://cyclonedx.org/bom","predicate":%s}' "$SAMPLE_SBOM")
      ENCODED_PAYLOAD=$(printf '%s' "$INTOTO_STATEMENT" | base64 -w0)
      DSSE_ENVELOPE=$(printf '{"payloadType":"application/vnd.in-toto+json","payload":"%s","signatures":[]}' "$ENCODED_PAYLOAD")

      # Mock crane
      cat > "${MOCK_BIN}/crane" <<'SCRIPT'
#!/bin/sh
if [ "$1" = "digest" ]; then
  echo "sha256:abcdef1234567890"
  exit 0
fi
exit 1
SCRIPT
      chmod +x "${MOCK_BIN}/crane"

      # Mock cosign that returns the DSSE envelope
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
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/extract-sbom-attestation --image postgres --pr 42 --sha abc1234 --output "$2/sbom/postgres.enriched.cdx.json"' _ "$MOCK_BIN" "$OUTPUT_DIR"
      The status should be success
      The stderr should include "Extracting SBOM attestation"
      The stderr should include "SBOM extracted"
    End

    It "creates the output directory if it does not exist"
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/extract-sbom-attestation --image postgres --pr 42 --sha abc1234 --output "$2/nested/dir/sbom.json"' _ "$MOCK_BIN" "$OUTPUT_DIR"
      The status should be success
      The stderr should include "SBOM extracted"
    End

    It "writes valid CycloneDX JSON"
      extract_sbom() {
        PATH="${MOCK_BIN}:$PATH" common/lib/scripts/extract-sbom-attestation \
          --image postgres --pr 42 --sha abc1234 \
          --output "${OUTPUT_DIR}/sbom.json" 2>/dev/null
        jq -r '.bomFormat' "${OUTPUT_DIR}/sbom.json"
      }
      When call extract_sbom
      The output should equal "CycloneDX"
    End

    It "resolves the PR tag correctly"
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/extract-sbom-attestation --image postgres --pr 42 --sha abc1234 --output "$2/sbom.json"' _ "$MOCK_BIN" "$OUTPUT_DIR"
      The stderr should include "pr-42-abc1234"
    End

    It "supports custom registry via --registry"
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/extract-sbom-attestation --image postgres --pr 42 --sha abc1234 --output "$2/sbom.json" --registry ghcr.io/custom/repo' _ "$MOCK_BIN" "$OUTPUT_DIR"
      The status should be success
      The stderr should include "ghcr.io/custom/repo/postgres"
    End

    It "supports custom registry via REGISTRY env var"
      When run sh -c 'PATH="$1:$PATH" REGISTRY=ghcr.io/env/repo common/lib/scripts/extract-sbom-attestation --image redis --pr 10 --sha def5678 --output "$2/sbom.json"' _ "$MOCK_BIN" "$OUTPUT_DIR"
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

      # cosign not needed — crane fails first
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

    It "fails when crane cannot resolve the PR tag"
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/extract-sbom-attestation --image postgres --pr 999 --sha missing --output "$2/sbom.json"' _ "$MOCK_BIN" "$OUTPUT_DIR"
      The status should be failure
      The stderr should include "PR tag"
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
      When run sh -c 'PATH="$1:$PATH" common/lib/scripts/extract-sbom-attestation --image postgres --pr 42 --sha abc1234 --output "$2/sbom.json"' _ "$MOCK_BIN" "$OUTPUT_DIR"
      The status should be failure
      The stderr should include "Extracting SBOM attestation"
    End
  End
End
