# shellcheck shell=sh
Describe "common/lib/scripts/create-release-notes"

  Describe "argument validation"
    It "fails when no arguments given"
      When run common/lib/scripts/create-release-notes
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --collection-version is missing"
      When run common/lib/scripts/create-release-notes \
        --pr-number 30 --app-version 0.27.0 --sha7 abc1234 \
        --matrix-json '[]' --output /tmp/notes.md
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --pr-number is missing"
      When run common/lib/scripts/create-release-notes \
        --collection-version sbomify-v0.27.0-20260329.1 --app-version 0.27.0 --sha7 abc1234 \
        --matrix-json '[]' --output /tmp/notes.md
      The status should be failure
      The output should include "Usage"
    End

    It "fails when --output is missing"
      When run common/lib/scripts/create-release-notes \
        --collection-version sbomify-v0.27.0-20260329.1 --pr-number 30 \
        --app-version 0.27.0 --sha7 abc1234 --matrix-json '[]'
      The status should be failure
      The output should include "Usage"
    End

    It "fails for unknown option"
      When run common/lib/scripts/create-release-notes --unknown value
      The status should be failure
      The output should include "Unknown option"
    End
  End

  Describe "release notes generation"
    setup() {
      MOCK_BIN="$(mktemp -d)"
      NOTES_FILE="$(mktemp)"

      cat > "${MOCK_BIN}/crane" <<'SCRIPT'
#!/bin/sh
if [ "$1" = "ls" ]; then
  case "$2" in
    */postgres)  echo "postgres-16.8-abc1234" ;;
    */redis)     echo "redis-8.0.2-abc1234" ;;
    *)           echo "unknown-1.0.0-abc1234" ;;
  esac
  exit 0
elif [ "$1" = "digest" ]; then
  echo "sha256:deadbeef12345678901234567890"
  exit 0
fi
exit 1
SCRIPT
      chmod +x "${MOCK_BIN}/crane"
    }

    cleanup() {
      rm -rf "$MOCK_BIN" "$NOTES_FILE"
    }
    Before "setup"
    After "cleanup"

    It "generates markdown with header and image table"
      When run sh -c '
        PATH="'"$MOCK_BIN"':$PATH" common/lib/scripts/create-release-notes \
          --collection-version sbomify-v0.27.0-20260329.1 \
          --pr-number 30 \
          --app-version 0.27.0 \
          --sha7 abc1234 \
          --matrix-json '\''[{"name":"postgres","package":"postgres-image"},{"name":"redis","package":"redis-image"}]'\'' \
          --output '"$NOTES_FILE"''
      The status should be success
      The output should include "## Collection: sbomify-v0.27.0-20260329.1"
      The output should include "**Source PR:** #30"
      The output should include "**App version:** 0.27.0"
      The output should include "postgres-16.8-abc1234"
      The output should include "redis-8.0.2-abc1234"
    End

    It "includes digest in table rows"
      When run sh -c '
        PATH="'"$MOCK_BIN"':$PATH" common/lib/scripts/create-release-notes \
          --collection-version sbomify-v0.27.0-20260329.1 \
          --pr-number 30 \
          --app-version 0.27.0 \
          --sha7 abc1234 \
          --matrix-json '\''[{"name":"postgres","package":"postgres-image"}]'\'' \
          --output '"$NOTES_FILE"''
      The status should be success
      The output should include "sha256:deadbeef1234"
    End

    It "supports custom registry via --registry"
      When run sh -c '
        PATH="'"$MOCK_BIN"':$PATH" common/lib/scripts/create-release-notes \
          --collection-version sbomify-v0.27.0-20260329.1 \
          --pr-number 30 \
          --app-version 0.27.0 \
          --sha7 abc1234 \
          --matrix-json '\''[{"name":"postgres","package":"postgres-image"}]'\'' \
          --output '"$NOTES_FILE"' \
          --registry ghcr.io/custom/repo'
      The status should be success
      The output should include "## Collection:"
    End
  End

  Describe "with empty matrix"
    setup_empty() {
      MOCK_BIN="$(mktemp -d)"
      NOTES_FILE="$(mktemp)"

      cat > "${MOCK_BIN}/crane" <<'SCRIPT'
#!/bin/sh
exit 0
SCRIPT
      chmod +x "${MOCK_BIN}/crane"
    }

    cleanup_empty() {
      rm -rf "$MOCK_BIN" "$NOTES_FILE"
    }
    Before "setup_empty"
    After "cleanup_empty"

    It "generates header with empty image table"
      When run sh -c '
        PATH="'"$MOCK_BIN"':$PATH" common/lib/scripts/create-release-notes \
          --collection-version sbomify-v0.27.0-20260329.1 \
          --pr-number 30 \
          --app-version 0.27.0 \
          --sha7 abc1234 \
          --matrix-json '\''[]'\'' \
          --output '"$NOTES_FILE"''
      The status should be success
      The output should include "## Collection:"
      The output should include "### Images"
    End
  End

  Describe "missing component tag"
    setup_no_tag() {
      MOCK_BIN="$(mktemp -d)"
      NOTES_FILE="$(mktemp)"

      cat > "${MOCK_BIN}/crane" <<'SCRIPT'
#!/bin/sh
if [ "$1" = "ls" ]; then
  echo "postgres-16.8-zzz9999"
  exit 0
fi
exit 1
SCRIPT
      chmod +x "${MOCK_BIN}/crane"
    }

    cleanup_no_tag() {
      rm -rf "$MOCK_BIN" "$NOTES_FILE"
    }
    Before "setup_no_tag"
    After "cleanup_no_tag"

    It "warns and skips images with no matching tag"
      When run sh -c '
        PATH="'"$MOCK_BIN"':$PATH" common/lib/scripts/create-release-notes \
          --collection-version sbomify-v0.27.0-20260329.1 \
          --pr-number 30 \
          --app-version 0.27.0 \
          --sha7 abc1234 \
          --matrix-json '\''[{"name":"postgres","package":"postgres-image"}]'\'' \
          --output '"$NOTES_FILE"' 2>&1'
      The status should be success
      The output should include "WARNING"
    End
  End
End
