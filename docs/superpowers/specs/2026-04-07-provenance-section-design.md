# Provenance Section Design

> **For agentic workers:** Use superpowers:executing-plans to implement the plan generated from this spec.

**Goal:** Add a top-level Provenance section to the sbomify release website showing SLSA build level evidence, per-image provenance data, and verification commands. Also move regulation evidence maps from the compliance landing page to the release homepage.

**Architecture:** Single flat page at `content/provenance/_index.md` with three sections (SLSA claim, image provenance table, verification commands). Regulation evidence maps relocated to release homepage as a cross-cutting navigation aid.

---

## Provenance Page

**File:** `content/provenance/_index.md` (top-level section)

**Frontmatter:**
```yaml
---
title: "Provenance"
description: "Build provenance, SLSA level evidence, and image verification for this release."
weight: 3
sidebar:
  open: true
---
```

### Section 1: SLSA Build Level

- Claim: SLSA Build L3 (v1.0 spec)
- Brief explanation of what Build L3 means
- Requirements-to-evidence table:

| Requirement | How We Meet It |
|---|---|
| Provenance exists | Attached as OCI attestation to every image |
| Hosted build platform | GitHub Actions |
| Authenticated provenance | Sigstore keyless signing via GitHub OIDC |
| Isolated builds | Nix sandbox + ephemeral CI runners |

- Note about reproducibility: "Nix builds are hermetic — the same inputs produce identical outputs. Verified reproducibility (independent rebuild comparison) is planned but not yet in CI."

### Section 2: Image Provenance Table

One row per image with key provenance fields:

| Image | Digest | Builder | Source Commit | Signed |
|---|---|---|---|---|
| postgres | `sha256:...` | GitHub Actions (linked to run) | commit SHA (linked) | Sigstore (keyless) |
| redis | ... | ... | ... | ... |
| ... | ... | ... | ... | ... |

- Sample data from postgres image (real format, placeholder values)
- Other 6 images show placeholder rows
- Note: "Full release data will be populated by the extraction script across all 7 images"
- Digests link to GHCR, source commits link to GitHub

### Section 3: Verification Commands

Copy-pasteable cosign commands using real GHCR image reference format (`ghcr.io/wellmaintained/packages/postgres:sbomify-v26.1.0-20260405.6`):

1. `cosign verify` — verify image signature
2. `cosign verify-attestation --type slsaprovenance` — verify and inspect provenance
3. `cosign verify-attestation --type cyclonedx` — verify SBOM attestation

---

## Compliance Landing Page Changes

**File:** `content/compliance/_index.md`

- Remove regulation evidence maps (Vendor Assessment, ISO 27001, CRA) — moved to homepage
- Keep "What's Included" table (Dependencies, Vulnerabilities, Licenses)
- Keep audit evidence pack placeholder

---

## Release Homepage Changes

**File:** `content/_index.md`

### Regulation Evidence Maps

Add below the three cards. Cross-references compliance and provenance sections by regulation:

All evidence links are relative to the homepage. Compliance subsections use `compliance/` prefix, provenance is top-level.

**Vendor Security Assessment:**

| Topic | Evidence |
|---|---|
| Software composition | [Dependencies](compliance/dependencies/) |
| Vulnerability management | [Vulnerabilities](compliance/vulnerabilities/) |
| Third-party risk | [Licenses](compliance/notices/) |
| Build integrity | [Provenance](provenance/) |

**ISO 27001:**

| Control | Evidence |
|---|---|
| A.8.8 Vulnerability management | [Vulnerabilities](compliance/vulnerabilities/) |
| A.8.28 Secure coding | [Dependencies](compliance/dependencies/) · [Provenance](provenance/) |
| A.8.30 Outsourced development | [Dependencies](compliance/dependencies/) · [Licenses](compliance/notices/) |

**CRA (Cyber Resilience Act):**

| Requirement | Evidence |
|---|---|
| Art.13 SBOM requirement | [Dependencies](compliance/dependencies/) |
| Art.13(6) Vulnerability handling | [Vulnerabilities](compliance/vulnerabilities/) |
| Art.13 Secure development | [Provenance](provenance/) |

### Card Link Updates

**Compliance card** — replace stale body with:
```html
<a href="compliance/dependencies/">Dependencies (SBOMs)</a><br>
<a href="compliance/vulnerabilities/">Vulnerability scans</a><br>
<a href="compliance/notices/">License notices</a>
```
Remove the stale "SLA: 7 days critical" line and "Compliance pack ZIP" link (audit pack is coming soon).

**Provenance card** — update "How it's built" link to `provenance/`

---

## Decisions

- **Provenance is top-level, not under compliance.** "How it was built" is a different concern from "what's in it." Matches existing homepage three-card layout.
- **Single page, not a section with sub-pages.** Provenance data is compact (SLSA claim + table + commands). Can be promoted to a section later if verified reproducibility or other evidence is added.
- **Evidence-first, not verification-first.** Primary audience is auditors filling out vendor assessments, not operators deploying images. Verification commands are included but secondary.
- **Regulation maps move to homepage.** They cross-cut all sections (compliance + provenance) and serve as navigation aids for specific regulatory frameworks. The homepage is the natural entry point.
- **Reproducibility is an unverified claim for now.** Nix provides hermetic builds but we don't yet rebuild-and-compare in CI. Noted honestly on the page.
