---
title: "Vulnerabilities"
description: "Vulnerability scan results and VEX triage decisions for this release, grouped by severity."
weight: 3
sidebar:
  open: true
---

All container images are scanned with [Grype](https://github.com/anchore/grype)
against the latest vulnerability database. Scans run weekly (Monday 06:00 UTC)
and on every pre-release build. Known false positives are suppressed via
per-image [VEX](https://openvex.dev) statements.

{{< vuln-summary-table >}}

## Methodology

1. SBOMs are extracted from OCI attestations attached to each container image
2. Grype scans each SBOM against the latest vulnerability database
3. Known false positives are suppressed via per-image VEX statements — the
   VEX status column shows the triage decision and justification
4. Remaining findings are triaged per the remediation SLA

VEX files follow the [OpenVEX v0.2.0](https://openvex.dev) specification and
serve dual purpose:

1. **Compliance evidence** — auditable record of triage decisions
2. **Scan suppression** — Grype consumes them via `--vex` to suppress known
   not-affected findings

## VEX Assessments

{{< vex-assessments >}}
