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
