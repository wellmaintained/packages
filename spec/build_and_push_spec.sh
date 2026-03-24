# shellcheck shell=sh
Describe "bin/build-and-push"

  Describe "subcommand dispatch"
    It "shows usage when no subcommand given"
      When run bin/build-and-push
      The status should be failure
      The stderr should include "Usage"
    End

    It "shows usage for unknown subcommand"
      When run bin/build-and-push foobar
      The status should be failure
      The stderr should include "Usage"
    End
  End

  Describe "metadata subcommand"
    It "fails when --package is missing"
      When run bin/build-and-push metadata
      The status should be failure
      The stderr should include "--package required"
    End

    It "fails for unknown option"
      When run bin/build-and-push metadata --bogus foo
      The status should be failure
      The stderr should include "Unknown option"
    End
  End

  Describe "build subcommand"
    It "fails when --package is missing"
      When run bin/build-and-push build
      The status should be failure
      The stderr should include "--package required"
    End
  End

  Describe "push subcommand"
    It "fails when --registry is missing"
      When run bin/build-and-push push --tag pr-1-abc
      The status should be failure
      The stderr should include "--registry and --tag required"
    End

    It "fails when --tag is missing"
      When run bin/build-and-push push --registry ghcr.io/example/img
      The status should be failure
      The stderr should include "--registry and --tag required"
    End
  End

  Describe "sbom subcommand"
    It "fails when --package is missing"
      When run bin/build-and-push sbom --name postgres
      The status should be failure
      The stderr should include "--package and --name required"
    End

    It "fails when --name is missing"
      When run bin/build-and-push sbom --package postgres-image
      The status should be failure
      The stderr should include "--package and --name required"
    End
  End

  Describe "sign subcommand"
    It "fails when --image-ref is missing"
      When run bin/build-and-push sign
      The status should be failure
      The stderr should include "--image-ref required"
    End
  End

  Describe "attest subcommand"
    It "fails when --image-ref is missing"
      When run bin/build-and-push attest --sbom-file foo.json
      The status should be failure
      The stderr should include "--image-ref required"
    End
  End

  Describe "provenance subcommand"
    It "fails when required args are missing"
      When run bin/build-and-push provenance --run-id 123
      The status should be failure
      The stderr should include "required"
    End

    Describe "JSON output"
      provenance_field() {
        bin/build-and-push provenance \
          --run-id 12345 \
          --server-url https://github.com \
          --repository wellmaintained/packages \
          --ref refs/pull/42/merge \
          --sha abc123def456 \
        | jq -r "$1"
      }

      It "outputs valid JSON"
        When run bin/build-and-push provenance \
          --run-id 12345 \
          --server-url https://github.com \
          --repository wellmaintained/packages \
          --ref refs/pull/42/merge \
          --sha abc123def456
        The status should be success
        The output should include "buildType"
      End

      It "sets the correct buildType"
        When call provenance_field '.buildType'
        The output should equal "https://github.com/wellmaintained/packages/build/nix/v1"
      End

      It "sets the builder ID from server_url, repository, and run_id"
        When call provenance_field '.builder.id'
        The output should equal "https://github.com/wellmaintained/packages/actions/runs/12345"
      End

      It "sets the config source URI"
        When call provenance_field '.invocation.configSource.uri'
        The output should equal "git+https://github.com/wellmaintained/packages@refs/pull/42/merge"
      End

      It "sets the commit SHA in config source digest"
        When call provenance_field '.invocation.configSource.digest.sha1'
        The output should equal "abc123def456"
      End

      It "sets the entryPoint"
        When call provenance_field '.invocation.configSource.entryPoint'
        The output should equal ".github/workflows/build.yml"
      End

      It "sets the buildInvocationId"
        When call provenance_field '.metadata.buildInvocationId'
        The output should equal "12345"
      End

      It "sets completeness parameters to true"
        When call provenance_field '.metadata.completeness.parameters'
        The output should equal "true"
      End

      It "sets completeness environment to false"
        When call provenance_field '.metadata.completeness.environment'
        The output should equal "false"
      End

      It "includes materials with correct URI"
        When call provenance_field '.materials[0].uri'
        The output should equal "git+https://github.com/wellmaintained/packages"
      End

      It "includes materials with correct SHA digest"
        When call provenance_field '.materials[0].digest.sha1'
        The output should equal "abc123def456"
      End
    End
  End
End
