# shellcheck shell=sh
Describe "common/lib/scripts/cleanup-stale-images"

  Describe "subcommand dispatch"
    It "shows usage when no subcommand given"
      When run common/lib/scripts/cleanup-stale-images
      The status should be failure
      The stderr should include "Usage"
    End

    It "shows usage for unknown subcommand"
      When run common/lib/scripts/cleanup-stale-images unknown
      The status should be failure
      The stderr should include "Usage"
    End
  End

  Describe "sweep subcommand"
    Describe "argument validation"
      It "fails when --image is missing"
        When run common/lib/scripts/cleanup-stale-images sweep
        The status should be failure
        The stderr should include "--image required"
      End

      It "fails for unknown option"
        When run common/lib/scripts/cleanup-stale-images sweep --bogus value
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
        When run sh -c 'PATH="$1:$PATH" common/lib/scripts/cleanup-stale-images sweep --image postgres' _ "$MOCK_BIN"
        The status should be success
        The stderr should include "Sweeping stale images for postgres"
        The stderr should include "no released-on tag"
      End

      It "deletes multiple found versions"
        When run sh -c 'PATH="$1:$PATH" common/lib/scripts/cleanup-stale-images sweep --image postgres' _ "$MOCK_BIN"
        The status should be success
        The stderr should include "Deleting version 67890"
        The stderr should include "Deleting version 67891"
        The stderr should include "Deleted 2 version(s)"
      End

      It "accepts custom --days parameter"
        When run sh -c 'PATH="$1:$PATH" common/lib/scripts/cleanup-stale-images sweep --image redis --days 14' _ "$MOCK_BIN"
        The status should be success
        The stderr should include "Sweeping stale images for redis"
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
        When run sh -c 'PATH="$1:$PATH" common/lib/scripts/cleanup-stale-images sweep --image postgres' _ "$MOCK_BIN"
        The status should be success
        The stderr should include "No matching images found"
      End
    End
  End
End
