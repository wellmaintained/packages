# shellcheck shell=sh
Describe "common/lib/scripts/patch-sbom-root"
  setup() {
    # Minimal bombon-like CycloneDX SBOM with a synthetic root component
    SAMPLE_SBOM='{
      "bomFormat": "CycloneDX",
      "specVersion": "1.5",
      "metadata": {
        "component": {
          "bom-ref": "pkg:nix/nixpkgs/postgres-closure",
          "type": "application",
          "name": "postgres-closure",
          "version": "0"
        }
      },
      "components": [
        {
          "bom-ref": "pkg:nix/nixpkgs/postgresql@17.4",
          "type": "application",
          "name": "postgresql",
          "version": "17.4",
          "licenses": [{"license": {"id": "PostgreSQL"}}]
        },
        {
          "bom-ref": "pkg:nix/nixpkgs/bash@5.2",
          "type": "application",
          "name": "bash",
          "version": "5.2",
          "licenses": [{"license": {"id": "GPL-3.0-or-later"}}]
        }
      ],
      "dependencies": []
    }'
  }
  Before "setup"

  all_args="--name wellmaintained/packages/postgres-image --version 17.4 --purl pkg:docker/wellmaintained/packages/postgres@17.4 --license PostgreSQL"

  Describe "argument validation"
    It "fails when --name is missing"
      When run sh -c 'echo "$1" | common/lib/scripts/patch-sbom-root --version 17.4 --purl pkg:docker/x/p@1 --license PostgreSQL' _ "$SAMPLE_SBOM"
      The status should be failure
      The stderr should include "--name"
    End

    It "fails when --version is missing"
      When run sh -c 'echo "$1" | common/lib/scripts/patch-sbom-root --name x --purl pkg:docker/x/p@1 --license PostgreSQL' _ "$SAMPLE_SBOM"
      The status should be failure
      The stderr should include "--version"
    End

    It "fails when --purl is missing"
      When run sh -c 'echo "$1" | common/lib/scripts/patch-sbom-root --name x --version 1 --license PostgreSQL' _ "$SAMPLE_SBOM"
      The status should be failure
      The stderr should include "--purl"
    End

    It "fails when --license is missing"
      When run sh -c 'echo "$1" | common/lib/scripts/patch-sbom-root --name x --version 1 --purl pkg:docker/x/p@1' _ "$SAMPLE_SBOM"
      The status should be failure
      The stderr should include "--license"
    End
  End

  Describe "root component patching"
    jq_query() {
      echo "$SAMPLE_SBOM" | common/lib/scripts/patch-sbom-root $all_args | jq -r "$1"
    }

    It "sets the root component name"
      When call jq_query '.metadata.component.name'
      The output should equal "wellmaintained/packages/postgres-image"
    End

    It "sets the root component version"
      When call jq_query '.metadata.component.version'
      The output should equal "17.4"
    End

    It "sets the root component type to container"
      When call jq_query '.metadata.component.type'
      The output should equal "container"
    End

    It "sets the root component purl"
      When call jq_query '.metadata.component.purl'
      The output should equal "pkg:docker/wellmaintained/packages/postgres@17.4"
    End

    It "sets the root component license"
      When call jq_query '.metadata.component.licenses[0].license.id'
      The output should equal "PostgreSQL"
    End

    It "preserves the original bom-ref"
      When call jq_query '.metadata.component["bom-ref"]'
      The output should equal "pkg:nix/nixpkgs/postgres-closure"
    End
  End

  Describe "dependency graph wiring"
    jq_query() {
      echo "$SAMPLE_SBOM" | common/lib/scripts/patch-sbom-root $all_args | jq -r "$1"
    }

    It "creates a dependency entry for the root component"
      When call jq_query '.dependencies[0].ref'
      The output should equal "pkg:nix/nixpkgs/postgres-closure"
    End

    It "lists all components as dependsOn of root"
      When call jq_query '.dependencies[0].dependsOn | length'
      The output should equal 2
    End

    It "includes postgresql in dependsOn"
      When call jq_query '.dependencies[0].dependsOn | sort | .[1]'
      The output should equal "pkg:nix/nixpkgs/postgresql@17.4"
    End

    It "includes bash in dependsOn"
      When call jq_query '.dependencies[0].dependsOn | sort | .[0]'
      The output should equal "pkg:nix/nixpkgs/bash@5.2"
    End
  End

  Describe "passthrough behavior"
    jq_query() {
      echo "$SAMPLE_SBOM" | common/lib/scripts/patch-sbom-root $all_args | jq -r "$1"
    }

    It "preserves bomFormat"
      When call jq_query '.bomFormat'
      The output should equal "CycloneDX"
    End

    It "preserves specVersion"
      When call jq_query '.specVersion'
      The output should equal "1.5"
    End

    It "preserves all components"
      When call jq_query '.components | length'
      The output should equal 2
    End

    It "preserves component details"
      When call jq_query '.components[0].name'
      The output should equal "postgresql"
    End
  End
End
