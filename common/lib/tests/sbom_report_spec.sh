# shellcheck shell=sh
Describe "common/lib/scripts/sbom-report"
  setup() {
    RESULTS_DIR="$(mktemp -d)"

    # Score result for postgres (improved)
    cat > "$RESULTS_DIR/score-postgres.json" <<'JSON'
{"image":"postgres","score":7.2,"num_components":24,"categories":[{"category":"Licensing","score":6.5}]}
JSON

    # Score result for redis (regressed)
    cat > "$RESULTS_DIR/score-redis.json" <<'JSON'
{"image":"redis","score":6.0,"num_components":8,"categories":[{"category":"Licensing","score":5.0}]}
JSON

    # Baseline scores
    cat > "$RESULTS_DIR/baseline-postgres.json" <<'JSON'
{"image":"postgres","score":7.0,"num_components":24,"categories":[{"category":"Licensing","score":6.0}]}
JSON

    cat > "$RESULTS_DIR/baseline-redis.json" <<'JSON'
{"image":"redis","score":6.5,"num_components":8,"categories":[{"category":"Licensing","score":5.5}]}
JSON

    # Compare result for postgres
    cat > "$RESULTS_DIR/compare-postgres.json" <<'JSON'
{"image":"postgres","diff_md":"1 component added","junit_xml":"<testsuites/>","policy_pass":true}
JSON

    # Compare result for redis
    cat > "$RESULTS_DIR/compare-redis.json" <<'JSON'
{"image":"redis","diff_md":"2 components removed","junit_xml":"<testsuites/>","policy_pass":true}
JSON
  }
  cleanup() {
    rm -rf "$RESULTS_DIR"
  }
  Before "setup"
  After "cleanup"

  Describe "argument validation"
    It "fails when --scores-dir is missing"
      When run common/lib/scripts/sbom-report
      The status should be failure
      The stderr should include "Usage"
    End
  End

  Describe "markdown output"
    It "produces a markdown table header"
      When run common/lib/scripts/sbom-report --scores-dir "$RESULTS_DIR"
      The output should include "SBOM Quality Gate"
      The output should include "Image"
      The output should include "Score"
      The stderr should include "regression"
      The status should be failure
    End

    It "includes image scores"
      When run common/lib/scripts/sbom-report --scores-dir "$RESULTS_DIR"
      The output should include "postgres"
      The output should include "7.2"
      The output should include "redis"
      The output should include "6.0"
      The stderr should include "regression"
      The status should be failure
    End

    It "shows score delta when baselines exist"
      When run common/lib/scripts/sbom-report --scores-dir "$RESULTS_DIR"
      The output should include "+0.2"
      The output should include "-0.5"
      The stderr should include "regression"
      The status should be failure
    End

    It "includes diff details in collapsible sections"
      When run common/lib/scripts/sbom-report --scores-dir "$RESULTS_DIR"
      The output should include "<details>"
      The output should include "1 component added"
      The stderr should include "regression"
      The status should be failure
    End
  End

  Describe "regression detection"
    It "exits non-zero when any score regresses"
      When run common/lib/scripts/sbom-report --scores-dir "$RESULTS_DIR"
      The status should be failure
      The stderr should include "regression"
      The output should include "SBOM Quality Gate"
    End

    It "exits zero when no regressions"
      # Remove the regressed redis baseline so redis has no baseline
      rm -f "$RESULTS_DIR/baseline-redis.json"
      When run common/lib/scripts/sbom-report --scores-dir "$RESULTS_DIR"
      The status should be success
      The output should include "postgres"
    End
  End

  Describe "no baseline scenario"
    It "shows N/A for images without baselines"
      rm -f "$RESULTS_DIR/baseline-postgres.json" "$RESULTS_DIR/baseline-redis.json"
      rm -f "$RESULTS_DIR/compare-postgres.json" "$RESULTS_DIR/compare-redis.json"
      When run common/lib/scripts/sbom-report --scores-dir "$RESULTS_DIR"
      The status should be success
      The output should include "N/A"
    End
  End
End
