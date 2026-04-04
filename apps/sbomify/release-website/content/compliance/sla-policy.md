---
title: "Vulnerability Remediation SLA"
description: "Service level agreements for vulnerability remediation in wellmaintained/packages images."
weight: 2
---

## Scan Schedule

All container images are rescanned weekly (Monday 06:00 UTC) against the latest
Grype vulnerability database. Scans also run on every pre-release build.

## Remediation SLAs

{{< sla-table >}}

## Triage Process

When a scan identifies a new vulnerability:

1. **Assess** — determine severity and whether the vulnerable code path is reachable
2. **Remediate** — update the affected package within the SLA window
3. **Document** — if not affected or mitigated, record a [VEX statement](vex-statements/) which also suppresses the finding in future scans

## Policy Source

This policy is defined in [`sla-policy.yaml`](https://github.com/wellmaintained/packages/blob/main/apps/sbomify/sla-policy.yaml)
and rendered here automatically.
