# shellcheck shell=sh
Describe "bin/promote-image"

  Describe "argument validation"
    It "fails when no arguments given"
      When run bin/promote-image
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --image is missing"
      When run bin/promote-image --pr 42 --sha abc1234 --version 17.4
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --pr is missing"
      When run bin/promote-image --image postgres --sha abc1234 --version 17.4
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --sha is missing"
      When run bin/promote-image --image postgres --pr 42 --version 17.4
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --version is missing"
      When run bin/promote-image --image postgres --pr 42 --sha abc1234
      The status should be failure
      The output should include "Usage"
    End

    It "fails for unknown option"
      When run bin/promote-image --unknown value
      The status should be failure
      The output should include "Unknown option"
    End
  End

  Describe "crane integration"
    setup() {
      MOCK_BIN="$(mktemp -d)"

      # Mock crane that simulates digest lookup and tagging
      cat > "${MOCK_BIN}/crane" <<'SCRIPT'
#!/bin/sh
if [ "$1" = "digest" ]; then
  echo "sha256:abcdef1234567890"
  exit 0
elif [ "$1" = "tag" ]; then
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

    It "calls crane digest with the correct PR tag"
      When run sh -c 'PATH="$1:$PATH" bin/promote-image --image postgres --pr 42 --sha abc1234 --version 17.4' _ "$MOCK_BIN"
      The status should be success
      The output should include "Promoting"
      The output should include "pr-42-abc1234"
    End

    It "prints the resolved digest"
      When run sh -c 'PATH="$1:$PATH" bin/promote-image --image postgres --pr 42 --sha abc1234 --version 17.4' _ "$MOCK_BIN"
      The status should be success
      The output should include "sha256:abcdef1234567890"
    End

    It "tags with latest, version, and version-calver"
      When run sh -c 'PATH="$1:$PATH" bin/promote-image --image postgres --pr 42 --sha abc1234 --version 17.4' _ "$MOCK_BIN"
      The status should be success
      The output should include "Tagging"
      The output should include "latest"
      The output should include "17.4"
    End

    It "prints promotion complete message"
      When run sh -c 'PATH="$1:$PATH" bin/promote-image --image postgres --pr 42 --sha abc1234 --version 17.4' _ "$MOCK_BIN"
      The status should be success
      The output should include "Promotion complete for postgres"
    End

    It "supports custom registry via --registry"
      When run sh -c 'PATH="$1:$PATH" bin/promote-image --image postgres --pr 42 --sha abc1234 --version 17.4 --registry ghcr.io/custom/repo' _ "$MOCK_BIN"
      The status should be success
      The output should include "ghcr.io/custom/repo/postgres"
    End

    It "supports custom registry via REGISTRY env var"
      When run sh -c 'PATH="$1:$PATH" REGISTRY=ghcr.io/env/repo bin/promote-image --image redis --pr 10 --sha def5678 --version 7.4' _ "$MOCK_BIN"
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

    It "fails when crane cannot resolve the PR tag"
      When run sh -c 'PATH="$1:$PATH" bin/promote-image --image postgres --pr 999 --sha missing --version 17.4' _ "$MOCK_BIN"
      The status should be failure
      The output should include "PR tag"
      The output should include "not found"
    End
  End

  Describe "sbomify upload handling"
    setup_with_sbom() {
      MOCK_BIN="$(mktemp -d)"
      SBOM_FILE="$(mktemp)"
      echo '{"bomFormat":"CycloneDX"}' > "$SBOM_FILE"
      cat > "${MOCK_BIN}/crane" <<'SCRIPT'
#!/bin/sh
if [ "$1" = "digest" ]; then echo "sha256:abc"; exit 0; fi
if [ "$1" = "tag" ]; then exit 0; fi
exit 1
SCRIPT
      chmod +x "${MOCK_BIN}/crane"
    }

    cleanup_with_sbom() {
      rm -rf "$MOCK_BIN" "$SBOM_FILE"
    }
    Before "setup_with_sbom"
    After "cleanup_with_sbom"

    It "skips sbomify upload when component ID is a placeholder"
      When run sh -c 'PATH="$1:$PATH" bin/promote-image --image minio --pr 1 --sha aaa --version 1.0 --sbomify-component-id PLACEHOLDER_MINIO --sbomify-token tok --sbom-file "$2"' _ "$MOCK_BIN" "$SBOM_FILE"
      The status should be success
      The output should include "placeholder"
    End

    It "warns when SBOM file does not exist"
      When run sh -c 'PATH="$1:$PATH" bin/promote-image --image pg --pr 1 --sha aaa --version 1.0 --sbomify-component-id ABC --sbomify-token tok --sbom-file /nonexistent' _ "$MOCK_BIN"
      The status should be success
      The output should include "WARNING"
      The output should include "not found"
    End
  End
End
