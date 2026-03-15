# shellcheck shell=sh
Describe "bin/sbom-compare"
  setup() {
    BASELINE="$(mktemp)"
    CURRENT="$(mktemp)"
    cat > "$BASELINE" <<'JSON'
{"bomFormat":"CycloneDX","specVersion":"1.5","components":[]}
JSON
    cat > "$CURRENT" <<'JSON'
{"bomFormat":"CycloneDX","specVersion":"1.5","components":[]}
JSON
    POLICY="$(mktemp)"
    cat > "$POLICY" <<'JSON'
{"deny_licenses":["GPL-3.0-only"],"require_licenses":true}
JSON
  }
  cleanup() {
    rm -f "$BASELINE" "$CURRENT" "$POLICY"
  }
  Before "setup"
  After "cleanup"

  Describe "argument validation"
    It "fails when no arguments are given"
      When run bin/sbom-compare
      The status should be failure
      The stderr should include "Usage"
    End

    It "fails when baseline file does not exist"
      When run bin/sbom-compare --baseline /nonexistent --current "$CURRENT" --image postgres
      The status should be failure
      The stderr should include "not found"
    End

    It "fails when current file does not exist"
      When run bin/sbom-compare --baseline "$BASELINE" --current /nonexistent --image postgres
      The status should be failure
      The stderr should include "not found"
    End

    It "fails when --image is missing"
      When run bin/sbom-compare --baseline "$BASELINE" --current "$CURRENT"
      The status should be failure
      The stderr should include "--image"
    End
  End

  Describe "sbomlyze integration"
    mock_sbomlyze() {
      MOCK="$(mktemp)"
      cat > "$MOCK" <<'SCRIPT'
#!/bin/sh
# Parse args to determine output format
for arg in "$@"; do
  case "$arg" in
    junit) cat <<'JUNIT'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites><testsuite name="SBOM Analysis" tests="2" failures="0"></testsuite></testsuites>
JUNIT
      exit 0 ;;
    markdown) cat <<'MD'
## SBOM Diff
- 1 component added
- 0 components removed
MD
      exit 0 ;;
  esac
done
# Default: text output, exit 0 for no policy violations
exit 0
SCRIPT
      chmod +x "$MOCK"
      echo "$MOCK"
    }

    cleanup_mock() {
      rm -f "$MOCK"
    }

    It "outputs JSON with image name and diff results"
      MOCK="$(mock_sbomlyze)"
      When run bin/sbom-compare --sbomlyze-cmd "$MOCK" --baseline "$BASELINE" --current "$CURRENT" --image postgres
      The status should be success
      The output should include '"image"'
      The output should include '"postgres"'
      cleanup_mock
    End

    jq_field() {
      MOCK="$(mock_sbomlyze)"
      bin/sbom-compare --sbomlyze-cmd "$MOCK" --baseline "$BASELINE" --current "$CURRENT" --image postgres | jq -r "$1"
      cleanup_mock
    }

    It "includes the markdown diff"
      When call jq_field '.diff_md'
      The output should include "SBOM Diff"
    End

    It "includes the junit XML"
      When call jq_field '.junit_xml'
      The output should include "testsuites"
    End

    It "reports policy_pass as true when no violations"
      When call jq_field '.policy_pass'
      The output should equal "true"
    End
  End

  Describe "policy violations"
    mock_sbomlyze_fail() {
      MOCK="$(mktemp)"
      cat > "$MOCK" <<'SCRIPT'
#!/bin/sh
for arg in "$@"; do
  case "$arg" in
    junit) echo '<testsuites><testsuite name="SBOM Analysis" tests="1" failures="1"></testsuite></testsuites>'; exit 0 ;;
    markdown) echo '## Diff'; exit 0 ;;
  esac
done
# Policy check run: exit 1 = violations found
exit 1
SCRIPT
      chmod +x "$MOCK"
      echo "$MOCK"
    }

    jq_field_fail() {
      MOCK="$(mock_sbomlyze_fail)"
      bin/sbom-compare --sbomlyze-cmd "$MOCK" --baseline "$BASELINE" --current "$CURRENT" --image postgres --policy "$POLICY" | jq -r "$1"
      rm -f "$MOCK"
    }

    It "reports policy_pass as false when violations detected"
      When call jq_field_fail '.policy_pass'
      The output should equal "false"
    End

    It "still succeeds (exit 0) even with policy violations"
      MOCK="$(mock_sbomlyze_fail)"
      When run bin/sbom-compare --sbomlyze-cmd "$MOCK" --baseline "$BASELINE" --current "$CURRENT" --image postgres --policy "$POLICY"
      The status should be success
      The output should include '"policy_pass"'
      rm -f "$MOCK"
    End
  End
End
