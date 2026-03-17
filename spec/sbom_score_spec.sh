# shellcheck shell=sh
Describe "bin/sbom-score"
  setup() {
    SBOM_FILE="$(mktemp)"
    cat > "$SBOM_FILE" <<'JSON'
{"bomFormat":"CycloneDX","specVersion":"1.5","components":[]}
JSON
  }
  cleanup() {
    rm -f "$SBOM_FILE"
  }
  Before "setup"
  After "cleanup"

  Describe "argument validation"
    It "fails when no SBOM file is given"
      When run bin/sbom-score
      The status should be failure
      The stderr should include "Usage"
    End

    It "fails when SBOM file does not exist"
      When run bin/sbom-score /nonexistent/file.json
      The status should be failure
      The stderr should include "not found"
    End
  End

  Describe "sbomqs integration"
    # Mock sbomqs to avoid requiring the real binary in tests
    mock_sbomqs() {
      # Create a fake sbomqs that outputs realistic JSON
      MOCK_SBOMQS="$(mktemp)"
      cat > "$MOCK_SBOMQS" <<'SCRIPT'
#!/bin/sh
cat <<'MOCK'
{"files":[{"avg_score":7.2,"num_components":24,"scores":[{"category":"Licensing","score":6.5,"max_score":10.0},{"category":"Structural","score":8.1,"max_score":10.0},{"category":"Completeness","score":7.0,"max_score":10.0}]}]}
MOCK
SCRIPT
      chmod +x "$MOCK_SBOMQS"
      echo "$MOCK_SBOMQS"
    }

    cleanup_mock() {
      rm -f "$MOCK_SBOMQS"
    }

    It "outputs valid JSON with score and image name"
      MOCK_SBOMQS="$(mock_sbomqs)"
      When run bin/sbom-score --sbomqs-cmd "$MOCK_SBOMQS" --image postgres "$SBOM_FILE"
      The status should be success
      The output should include '"image"'
      The output should include '"score"'
      cleanup_mock
    End

    jq_field() {
      MOCK_SBOMQS="$(mock_sbomqs)"
      bin/sbom-score --sbomqs-cmd "$MOCK_SBOMQS" --image postgres "$SBOM_FILE" | jq -r "$1"
      cleanup_mock
    }

    It "extracts the average score"
      When call jq_field '.score'
      The output should equal "7.2"
    End

    It "includes the image name"
      When call jq_field '.image'
      The output should equal "postgres"
    End

    It "includes the component count"
      When call jq_field '.num_components'
      The output should equal "24"
    End

    It "includes category scores"
      When call jq_field '.categories | length'
      The output should equal "3"
    End

    It "includes Licensing category score"
      When call jq_field '.categories[] | select(.category == "Licensing") | .score'
      The output should equal "6.5"
    End
  End

  Describe "sbomqs failure handling"
    It "fails when sbomqs returns an error"
      MOCK_FAIL="$(mktemp)"
      printf '#!/bin/sh\necho "error" >&2\nexit 1\n' > "$MOCK_FAIL"
      chmod +x "$MOCK_FAIL"
      When run bin/sbom-score --sbomqs-cmd "$MOCK_FAIL" --image postgres "$SBOM_FILE"
      The status should be failure
      The stderr should include "sbomqs"
      rm -f "$MOCK_FAIL"
    End
  End
End
