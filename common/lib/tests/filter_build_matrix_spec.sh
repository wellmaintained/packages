# shellcheck shell=sh
Describe "common/lib/scripts/filter-build-matrix"
  setup() {
    MATRIX_FILE="$(mktemp)"
    CHANGED_FILE="$(mktemp)"
    # Use app-level paths for per-image filtering tests (common/images/* triggers rebuild-all)
    cat > "$MATRIX_FILE" <<'JSON'
[
  {"name":"sbomify-app","package":"sbomify-app-image","paths":["apps/sbomify/images/sbomify-app.nix","apps/sbomify/deployments/build-support/"]},
  {"name":"sbomify-keycloak","package":"sbomify-keycloak-image","paths":["apps/sbomify/images/sbomify-keycloak.nix"]},
  {"name":"postgres","package":"postgres-image","paths":["common/images/postgres.nix"]}
]
JSON
  }
  cleanup() {
    rm -f "$MATRIX_FILE" "$CHANGED_FILE"
  }
  Before "setup"
  After "cleanup"

  Describe "argument validation"
    It "fails when no arguments are given"
      When run common/lib/scripts/filter-build-matrix
      The status should be failure
      The stderr should include "Usage"
    End

    It "fails when only one argument is given"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE"
      The status should be failure
      The stderr should include "Usage"
    End

    It "fails when matrix file does not exist"
      When run common/lib/scripts/filter-build-matrix /nonexistent/matrix.json "$CHANGED_FILE"
      The status should be failure
      The stderr should include "not found"
    End

    It "fails when changed-files file does not exist"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE" /nonexistent/changed.txt
      The status should be failure
      The stderr should include "not found"
    End
  End

  Describe "rebuild-all triggers"
    It "rebuilds all when flake.nix is changed"
      echo "flake.nix" > "$CHANGED_FILE"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE" "$CHANGED_FILE"
      The status should be success
      The output should include '"postgres"'
      The output should include '"sbomify-app"'
      The output should include '"sbomify-keycloak"'
      The stderr should include "Rebuild-all"
    End

    It "rebuilds all when flake.lock is changed"
      echo "flake.lock" > "$CHANGED_FILE"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE" "$CHANGED_FILE"
      The status should be success
      The output should include '"postgres"'
      The stderr should include "Rebuild-all"
    End

    It "rebuilds all when common/lib/ file is changed"
      echo "common/lib/scripts/build-and-push" > "$CHANGED_FILE"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE" "$CHANGED_FILE"
      The status should be success
      The output should include '"postgres"'
      The output should include '"sbomify-app"'
      The stderr should include "Rebuild-all"
    End

    It "rebuilds all when common/pkgs/ file is changed"
      echo "common/pkgs/something.nix" > "$CHANGED_FILE"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE" "$CHANGED_FILE"
      The status should be success
      The output should include '"postgres"'
      The stderr should include "Rebuild-all"
    End

    It "rebuilds all when common/images/ file is changed"
      echo "common/images/base.nix" > "$CHANGED_FILE"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE" "$CHANGED_FILE"
      The status should be success
      The output should include '"postgres"'
      The stderr should include "Rebuild-all"
    End

    It "rebuilds all when build.yml is changed"
      echo ".github/workflows/build.yml" > "$CHANGED_FILE"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE" "$CHANGED_FILE"
      The status should be success
      The output should include '"postgres"'
      The stderr should include "Rebuild-all"
    End

    It "rebuilds all when image-matrix.json is changed"
      echo ".github/image-matrix.json" > "$CHANGED_FILE"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE" "$CHANGED_FILE"
      The status should be success
      The output should include '"postgres"'
      The stderr should include "Rebuild-all"
    End

    It "strips .paths from output on rebuild-all"
      echo "flake.nix" > "$CHANGED_FILE"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE" "$CHANGED_FILE"
      The status should be success
      The output should not include '"paths"'
      The stderr should include "Rebuild-all"
    End
  End

  Describe "per-image path filtering"
    It "returns only the image whose path matched"
      echo "apps/sbomify/images/sbomify-app.nix" > "$CHANGED_FILE"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE" "$CHANGED_FILE"
      The status should be success
      The output should include '"sbomify-app"'
      The output should not include '"sbomify-keycloak"'
      The output should not include '"postgres"'
      The stderr should include "Building filtered"
    End

    It "returns multiple images when multiple paths match"
      printf "apps/sbomify/images/sbomify-app.nix\napps/sbomify/images/sbomify-keycloak.nix\n" > "$CHANGED_FILE"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE" "$CHANGED_FILE"
      The status should be success
      The output should include '"sbomify-app"'
      The output should include '"sbomify-keycloak"'
      The output should not include '"postgres"'
      The stderr should include "Building filtered"
    End

    It "matches prefix paths (directory-level paths)"
      echo "apps/sbomify/deployments/build-support/Dockerfile" > "$CHANGED_FILE"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE" "$CHANGED_FILE"
      The status should be success
      The output should include '"sbomify-app"'
      The output should not include '"postgres"'
      The stderr should include "Building filtered"
    End

    It "strips .paths from filtered output"
      echo "apps/sbomify/images/sbomify-app.nix" > "$CHANGED_FILE"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE" "$CHANGED_FILE"
      The status should be success
      The output should not include '"paths"'
      The stderr should include "Building filtered"
    End
  End

  Describe "no matches"
    It "returns empty array when no paths match"
      echo "README.md" > "$CHANGED_FILE"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE" "$CHANGED_FILE"
      The status should be success
      The output should equal "[]"
      The stderr should include "No image paths changed"
    End

    It "returns empty array for empty changed-files"
      : > "$CHANGED_FILE"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE" "$CHANGED_FILE"
      The status should be success
      The output should equal "[]"
      The stderr should include "No image paths changed"
    End
  End

  Describe "rebuild-all takes precedence"
    It "rebuilds all even when a specific app path also matches"
      printf "flake.nix\napps/sbomify/images/sbomify-app.nix\n" > "$CHANGED_FILE"
      When run common/lib/scripts/filter-build-matrix "$MATRIX_FILE" "$CHANGED_FILE"
      The status should be success
      The output should include '"postgres"'
      The output should include '"sbomify-app"'
      The output should include '"sbomify-keycloak"'
      The stderr should include "Rebuild-all"
    End
  End
End
