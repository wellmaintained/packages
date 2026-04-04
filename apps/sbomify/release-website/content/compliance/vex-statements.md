---
title: "VEX Statements"
description: "Vulnerability Exploitability eXchange (VEX) triage decisions for wellmaintained/packages."
weight: 4
---

## What is VEX?

VEX (Vulnerability Exploitability eXchange) provides formal statements about
whether a reported vulnerability actually affects a given product. When a CVE
is reported against a dependency but is not exploitable in our deployment, a
VEX statement documents that decision with rationale.

## Current VEX Statements

*No VEX statements have been issued yet. As vulnerabilities are triaged,
formal not-affected and mitigated decisions will appear here.*

## Format

VEX documents follow the [OpenVEX](https://openvex.dev/) specification, authored
as YAML and stored next to each image's Nix definition:

- `common/images/{name}.vex.yaml` — infrastructure images
- `apps/sbomify/images/{name}.vex.yaml` — application images

VEX files serve dual purpose: they are converted to JSON and passed to Grype
via `--vex` to suppress findings at scan time, and rendered here as compliance
evidence.

Each document records:
- The CVE identifier
- The affected product (container image)
- The status (`not_affected` or `mitigated`)
- A justification explaining why the vulnerability does not apply
- A timestamp for audit trail purposes
