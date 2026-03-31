# shellcheck shell=sh
Describe "common/lib/scripts/parse-release-images"

  Describe "parsing a standard release body"
    It "extracts image name and digest from a backtick-wrapped table row"
      Data
        #|| `postgres` | `postgres-17.9-47953a4` | `sha256:84d1947c6c0d` |
      End
      When run common/lib/scripts/parse-release-images
      The output should equal "postgres sha256:84d1947c6c0d"
      The status should be success
    End

    It "handles multiple rows"
      Data
        #|| `postgres` | `postgres-17.9-47953a4` | `sha256:84d1947c6c0d` |
        #|| `redis` | `redis-8.2.3-47953a4` | `sha256:3ba1586e8e6c` |
        #|| `minio` | `minio-2025-10-15T17-29-55Z-47953a4` | `sha256:d334476091e0` |
      End
      When run common/lib/scripts/parse-release-images
      The line 1 should equal "postgres sha256:84d1947c6c0d"
      The line 2 should equal "redis sha256:3ba1586e8e6c"
      The line 3 should equal "minio sha256:d334476091e0"
      The status should be success
    End
  End

  Describe "backtick handling"
    It "strips backticks from image names and digests"
      Data
        #|| `sbomify-app` | `sbomify-app-0.27.0-47953a4` | `sha256:22917392d6ad` |
      End
      When run common/lib/scripts/parse-release-images
      The output should equal "sbomify-app sha256:22917392d6ad"
      The output should not include '`'
      The status should be success
    End

    It "works when table cells have no backticks"
      Data
        #|| postgres | postgres-17.9-47953a4 | sha256:84d1947c6c0d |
      End
      When run common/lib/scripts/parse-release-images
      The output should equal "postgres sha256:84d1947c6c0d"
      The status should be success
    End

    It "works when table cells have extra whitespace around backticks"
      Data
        #||  `postgres`  |  `postgres-17.9-47953a4`  |  `sha256:84d1947c6c0d`  |
      End
      When run common/lib/scripts/parse-release-images
      The output should equal "postgres sha256:84d1947c6c0d"
      The status should be success
    End
  End

  Describe "filtering"
    It "skips the table header row"
      Data
        #|| Image | Component Tag | Digest |
        #||-------|--------------|--------|
        #|| `postgres` | `postgres-17.9-47953a4` | `sha256:84d1947c6c0d` |
      End
      When run common/lib/scripts/parse-release-images
      The output should equal "postgres sha256:84d1947c6c0d"
      The status should be success
    End

    It "skips non-table lines in the release body"
      Data
        #|## Collection: sbomify-v0.27.0-20260329.1
        #|
        #|**Source PR:** #30
        #|**App version:** 0.27.0
        #|
        #|### Images
        #|
        #|| Image | Component Tag | Digest |
        #||-------|--------------|--------|
        #|| `postgres` | `postgres-17.9-47953a4` | `sha256:84d1947c6c0d` |
      End
      When run common/lib/scripts/parse-release-images
      The output should equal "postgres sha256:84d1947c6c0d"
      The status should be success
    End

    It "produces no output for a release body with no image table"
      Data
        #|## Collection: sbomify-v0.27.0-20260329.1
        #|
        #|**Source PR:** #30
        #|**App version:** 0.27.0
      End
      When run common/lib/scripts/parse-release-images
      The output should equal ""
      The status should be success
    End
  End

  Describe "edge cases"
    It "handles hyphenated image names like sbomify-caddy-dev"
      Data
        #|| `sbomify-caddy-dev` | `sbomify-caddy-dev-2.11.2-47953a4` | `sha256:0babbf5f05a5` |
      End
      When run common/lib/scripts/parse-release-images
      The output should equal "sbomify-caddy-dev sha256:0babbf5f05a5"
      The status should be success
    End

    It "handles image names with init suffix like sbomify-minio-init"
      Data
        #|| `sbomify-minio-init` | `sbomify-minio-init-0.27.0-47953a4` | `sha256:20a941c9d32c` |
      End
      When run common/lib/scripts/parse-release-images
      The output should equal "sbomify-minio-init sha256:20a941c9d32c"
      The status should be success
    End

    It "handles the full realistic release body from a real release"
      Data
        #|## Collection: sbomify-v0.27.0-20260331.1
        #|
        #|**Source PR:** #40
        #|**App version:** 0.27.0
        #|
        #|### Images
        #|
        #|| Image | Component Tag | Digest |
        #||-------|--------------|--------|
        #|| `postgres` | `postgres-17.9-47953a4` | `sha256:84d1947c6c0d` |
        #|| `redis` | `redis-8.2.3-47953a4` | `sha256:3ba1586e8e6c` |
        #|| `minio` | `minio-2025-10-15T17-29-55Z-47953a4` | `sha256:d334476091e0` |
        #|| `sbomify-app` | `sbomify-app-0.27.0-47953a4` | `sha256:22917392d6ad` |
        #|| `sbomify-keycloak` | `sbomify-keycloak-26.5.6-47953a4` | `sha256:6d155562d3fc` |
        #|| `sbomify-caddy-dev` | `sbomify-caddy-dev-2.11.2-47953a4` | `sha256:0babbf5f05a5` |
        #|| `sbomify-minio-init` | `sbomify-minio-init-0.27.0-47953a4` | `sha256:20a941c9d32c` |
      End
      When run common/lib/scripts/parse-release-images
      The line 1 should equal "postgres sha256:84d1947c6c0d"
      The line 2 should equal "redis sha256:3ba1586e8e6c"
      The line 3 should equal "minio sha256:d334476091e0"
      The line 4 should equal "sbomify-app sha256:22917392d6ad"
      The line 5 should equal "sbomify-keycloak sha256:6d155562d3fc"
      The line 6 should equal "sbomify-caddy-dev sha256:0babbf5f05a5"
      The line 7 should equal "sbomify-minio-init sha256:20a941c9d32c"
      The lines of output should equal 7
      The status should be success
    End

    It "skips rows where digest column is empty"
      Data
        #|| `postgres` | `postgres-17.9-47953a4` |  |
      End
      When run common/lib/scripts/parse-release-images
      The output should equal ""
      The status should be success
    End

    It "skips rows where name column is empty"
      Data
        #||  | `postgres-17.9-47953a4` | `sha256:84d1947c6c0d` |
      End
      When run common/lib/scripts/parse-release-images
      The output should equal ""
      The error should include "Skipping unparseable row"
      The status should be success
    End
  End
End
