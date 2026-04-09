# Compliance Section Redesign

## Goal

Redesign the compliance section of the sbomify release website to serve auditors compiling evidence for vendor assessments, ISO 27001 control evidence, and CRA regulation assessments — leading with a downloadable audit evidence pack and providing browsable, per-image compliance artifacts.

## Audiences

- **Security/compliance auditors** evaluating sbomify for approval (vendor security questionnaires, ISO 27001 audits, CRA assessments)
- **Operators** who've deployed sbomify and need to demonstrate compliance to their own auditors

Primary goal: "Here are the exact compliance artifacts I need to attach to my assessment" — practical, download-and-go. Secondary goal: signal professionalism and rigour through presentation.

## Architecture

Artifact-type sections with release-level summary pages and per-image drill-down pages. One audit evidence ZIP containing all artifacts, with per-regulation evidence maps on the landing page showing which artifacts satisfy which requirements.

## Site Structure

```
compliance/
├── _index.md                  — Audit pack download + what's included + regulation evidence maps
├── sboms/
│   ├── _index.md              — Release-level SBOM summary table (all 7 images)
│   └── {image}.md             — Per-image: collapsible component tree + JSON download (×7, CI-generated)
├── vulnerability-status/
│   ├── _index.md              — Release-level CVE summary table
│   └── {image}.md             — Per-image CVE list (×7, CI-generated)
├── vex-statements.md          — All VEX justifications in one view
├── sla-policy.md              — Remediation SLA table + triage process
├── support-period.md          — CRA Art.13(19) stub (coming soon)
├── disclosure-policy.md       — CRA Art.13(6) stub (coming soon)
├── security-updates.md        — CRA update mechanism stub (coming soon)
├── sdlc.md                    — ISO 27001 A.8.25/A.8.28 stub (coming soon)
└── config-management.md       — ISO 27001 A.8.9 stub (coming soon)
```

Supporting files:
- `assets/js/sbom-tree.js` — Collapsible component tree viewer (vanilla JS, no dependencies)
- `static/artifacts/sboms/{image}.cdx.json` — Raw SBOM files (CI-extracted from OCI attestations)

## Page Designs

### Landing Page (`_index.md`)

Three sections:

1. **Audit Evidence Pack** (hero) — prominent download button for combined ZIP, one-line description (release tag, image count, contents). Coming-soon note until CI generates the ZIP.

2. **What's Included** — table with one row per artifact type: SBOMs, Vulnerability Scans, VEX Statements, SLA Policy. Each row: name, brief description, status (available/planned), link to section. Also lists planned items: License Analysis, SBOM Quality Scores.

3. **Regulation Evidence Maps** — three sections mapping framework requirements to artifacts:
   - **Vendor Security Assessment**: software composition → SBOMs, vulnerability management → Vuln Status + SLA, third-party risk → License Analysis (planned)
   - **ISO 27001**: A.8.8 → Vuln Status + SLA, A.8.25 → SDLC (planned), A.8.28 → SBOMs + SDLC (planned), A.8.9 → Config Mgmt (planned), A.8.30 → SBOMs + License Analysis (planned)
   - **CRA**: Art.13 SBOM → SBOMs, Art.13(6) → VEX + Disclosure Policy (planned), Art.13(19) → Support Period (planned), Security updates → Sec Updates (planned)

### SBOMs Index (`sboms/_index.md`)

- Brief intro: CycloneDX SBOMs for all container images, attached as OCI attestations
- Table: image name (links to detail page), upstream version, component count, SBOM format
- Note on SBOM generation process (Nix derivation → attached via cosign)
- Planned items on this page: license analysis, sbomqs quality scores

### SBOMs Per-Image (`sboms/{image}.md`)

- Header: image name, upstream version, component count, CycloneDX spec version
- Download link for raw CycloneDX JSON
- **Collapsible component tree viewer**: interactive tree built from CycloneDX `components` + `dependencies` arrays, showing component name, version, and license. Default 3 levels expanded. Expand all / Collapse all / Search controls.
- Planned: sbomqs quality score

### SBOM Tree Viewer (`assets/js/sbom-tree.js`)

- ~100-150 lines vanilla JS, zero dependencies
- Reads CycloneDX JSON from a static file path
- Parses `components` and `dependencies` arrays to build a dependency tree
- Renders as nested HTML with click-to-expand/collapse
- Each node: component name, version, license badge
- Collapsed nodes show "+" child count
- Controls: expand all, collapse all, search/filter
- Invoked via Hugo shortcode on per-image pages

### Vulnerability Status Index (`vulnerability-status/_index.md`)

- Brief intro: Grype scan results, rescanned weekly
- Table: image name (links to detail page), upstream version, CVE count by severity (critical/high/medium/low), last scanned date
- Release-level totals row

### Vulnerability Status Per-Image (`vulnerability-status/{image}.md`)

- Full CVE list: CVE ID, severity, affected package, fixed-in version, VEX status (cross-link if justification exists)
- CI-generated from Grype scan results

### VEX Statements (`vex-statements.md`)

- Brief intro: what VEX is, link to OpenVEX spec
- Table of all active VEX statements: CVE ID, affected image(s), status, justification, date
- If none: "No VEX statements have been issued for this release"
- VEX files parsed from repo at build time

### SLA Policy (`sla-policy.md`)

- Scan schedule: weekly Monday 06:00 UTC + every pre-release
- SLA table rendered from `sla_policy.yaml` via existing `sla-table` shortcode
- Triage process: Assess → Remediate → Document

### Coming Soon Stubs (5 pages)

Each stub page has a one-paragraph description and which regulation requires it:

- `support-period.md` — CRA Article 13(19): how long security updates will be provided
- `disclosure-policy.md` — CRA Article 13(6): how to report vulnerabilities and expected response
- `security-updates.md` — CRA: how operators receive and apply security patches
- `sdlc.md` — ISO 27001 A.8.25/A.8.28: Nix builds, reproducibility, CI pipeline
- `config-management.md` — ISO 27001 A.8.9: how image configurations are controlled and versioned

## Key Decisions

1. **Single audit pack ZIP with per-regulation evidence maps on the website** — one set of artifacts, multiple guided paths through them per framework. Maps live on the landing page, not in the ZIP.

2. **SBOMs bundled in the website** — CI extracts SBOMs from OCI attestations and includes them as static assets. Auditors download directly, no `cosign` CLI needed.

3. **Collapsible component tree viewer** — vanilla JS, parses CycloneDX JSON, renders interactive dependency tree with 3 levels expanded by default. Search and expand/collapse controls.

4. **Per-image detail pages are CI-generated** — templates defined in this implementation, but actual content populated by CI extracting data from SBOMs and scan results. For v1, we create example/template pages.

5. **Coming-soon items live on the page where they'll eventually be implemented** — no separate "coming soon" page. Items without a natural home (CRA/ISO stubs) get their own stub pages with coming-soon banners.

6. **Future enhancement: Sunshine starburst visualization** — CycloneDX Sunshine generates interactive HTML from SBOMs. Deferred to a future iteration.
