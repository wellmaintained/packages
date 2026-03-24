# shellcheck shell=sh
Describe "bin/cleanup-pr-images"

  Describe "subcommand dispatch"
    It "shows usage when no subcommand given"
      When run bin/cleanup-pr-images
      The status should be failure
      The stderr should include "Usage"
    End

    It "shows usage for unknown subcommand"
      When run bin/cleanup-pr-images unknown
      The status should be failure
      The stderr should include "Usage"
    End
  End

  Describe "pr subcommand"
    Describe "argument validation"
      It "fails when --image is missing"
        When run bin/cleanup-pr-images pr --pr-number 42
        The status should be failure
        The stderr should include "--image and --pr-number required"
      End

      It "fails when --pr-number is missing"
        When run bin/cleanup-pr-images pr --image postgres
        The status should be failure
        The stderr should include "--image and --pr-number required"
      End

      It "fails for unknown option"
        When run bin/cleanup-pr-images pr --bogus value
        The status should be failure
        The stderr should include "Unknown option"
      End
    End

    Describe "gh api integration"
      setup_gh_mock() {
        MOCK_BIN="$(mktemp -d)"
        GH_LOG="${MOCK_BIN}/gh.log"
        # Mock gh that returns version IDs matching the PR
        cat > "${MOCK_BIN}/gh" <<'SCRIPT'
#!/bin/sh
echo "gh $*" >> "${0%/*}/gh.log"
if echo "$*" | grep -q "method DELETE"; then
  exit 0
elif echo "$*" | grep -q "versions"; then
  # Simulate finding one matching version
  echo "12345"
  exit 0
fi
exit 0
SCRIPT
        chmod +x "${MOCK_BIN}/gh"
      }

      cleanup_gh_mock() {
        rm -rf "$MOCK_BIN"
      }
      Before "setup_gh_mock"
      After "cleanup_gh_mock"

      It "calls gh api to list versions for the correct image"
        When run sh -c 'PATH="$1:$PATH" bin/cleanup-pr-images pr --image postgres --pr-number 42' _ "$MOCK_BIN"
        The status should be success
        The stderr should include "Cleaning up pr-42 images for postgres"
      End

      It "deletes found versions"
        When run sh -c 'PATH="$1:$PATH" bin/cleanup-pr-images pr --image postgres --pr-number 42' _ "$MOCK_BIN"
        The status should be success
        The stderr should include "Deleting version 12345"
        The stderr should include "Deleted 1 version(s)"
      End

      It "respects GHCR_ORG environment variable"
        When run sh -c 'PATH="$1:$PATH" GHCR_ORG=myorg bin/cleanup-pr-images pr --image redis --pr-number 10' _ "$MOCK_BIN"
        The status should be success
        The stderr should include "Cleaning up pr-10 images for redis"
      End
    End

    Describe "no images found"
      setup_empty_gh_mock() {
        MOCK_BIN="$(mktemp -d)"
        cat > "${MOCK_BIN}/gh" <<'SCRIPT'
#!/bin/sh
# Return empty for list, succeed for everything else
if echo "$*" | grep -q "versions" && ! echo "$*" | grep -q "DELETE"; then
  exit 0
fi
exit 0
SCRIPT
        chmod +x "${MOCK_BIN}/gh"
      }

      cleanup_empty_gh_mock() {
        rm -rf "$MOCK_BIN"
      }
      Before "setup_empty_gh_mock"
      After "cleanup_empty_gh_mock"

      It "handles no matching images gracefully"
        When run sh -c 'PATH="$1:$PATH" bin/cleanup-pr-images pr --image postgres --pr-number 999' _ "$MOCK_BIN"
        The status should be success
        The stderr should include "No matching images found"
      End
    End
  End

  Describe "sweep subcommand"
    Describe "argument validation"
      It "fails when --image is missing"
        When run bin/cleanup-pr-images sweep
        The status should be failure
        The stderr should include "--image required"
      End

      It "fails for unknown option"
        When run bin/cleanup-pr-images sweep --bogus value
        The status should be failure
        The stderr should include "Unknown option"
      End
    End

    Describe "gh api integration"
      setup_sweep_mock() {
        MOCK_BIN="$(mktemp -d)"
        cat > "${MOCK_BIN}/gh" <<'SCRIPT'
#!/bin/sh
if echo "$*" | grep -q "method DELETE"; then
  exit 0
elif echo "$*" | grep -q "versions"; then
  echo "67890"
  echo "67891"
  exit 0
fi
exit 0
SCRIPT
        chmod +x "${MOCK_BIN}/gh"
      }

      cleanup_sweep_mock() {
        rm -rf "$MOCK_BIN"
      }
      Before "setup_sweep_mock"
      After "cleanup_sweep_mock"

      It "sweeps stale images with default 7 day cutoff"
        When run sh -c 'PATH="$1:$PATH" bin/cleanup-pr-images sweep --image postgres' _ "$MOCK_BIN"
        The status should be success
        The stderr should include "Sweeping stale PR images for postgres"
      End

      It "deletes multiple found versions"
        When run sh -c 'PATH="$1:$PATH" bin/cleanup-pr-images sweep --image postgres' _ "$MOCK_BIN"
        The status should be success
        The stderr should include "Deleting version 67890"
        The stderr should include "Deleting version 67891"
        The stderr should include "Deleted 2 version(s)"
      End

      It "accepts custom --days parameter"
        When run sh -c 'PATH="$1:$PATH" bin/cleanup-pr-images sweep --image redis --days 14' _ "$MOCK_BIN"
        The status should be success
        The stderr should include "Sweeping stale PR images for redis"
      End
    End

    Describe "no stale images"
      setup_empty_sweep_mock() {
        MOCK_BIN="$(mktemp -d)"
        cat > "${MOCK_BIN}/gh" <<'SCRIPT'
#!/bin/sh
if echo "$*" | grep -q "versions" && ! echo "$*" | grep -q "DELETE"; then
  exit 0
fi
exit 0
SCRIPT
        chmod +x "${MOCK_BIN}/gh"
      }

      cleanup_empty_sweep_mock() {
        rm -rf "$MOCK_BIN"
      }
      Before "setup_empty_sweep_mock"
      After "cleanup_empty_sweep_mock"

      It "handles no stale images gracefully"
        When run sh -c 'PATH="$1:$PATH" bin/cleanup-pr-images sweep --image postgres' _ "$MOCK_BIN"
        The status should be success
        The stderr should include "No matching images found"
      End
    End
  End
End
