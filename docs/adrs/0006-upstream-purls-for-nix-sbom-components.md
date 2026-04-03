# 0006. Use upstream ecosystem PURLs for Nix SBOM components

Date: 2026-04-04

## Status

proposed

## Context

Nix-built SBOMs need Package URLs (PURLs) that vulnerability scanners can
match against known vulnerability databases. The SBOM transformer originally
emitted `pkg:nix/` PURLs as the primary identifier for all components. No
vulnerability scanner understands `pkg:nix/` — it returns zero results from
every database.

### The vulnerability database landscape

There are two tracks in the industry:

- **CPE-based (NVD):** The legacy approach. CPE identifiers are ambiguous
  (vendor/product naming is inconsistent), NVD enrichment has chronic funding
  and staffing issues, and matching quality is inherently lossy.

- **PURL-based (OSV, GitHub Advisory, Snyk):** The modern approach. Package
  names map 1:1 to registry names. OSV aggregates 30+ sources including all
  GitHub Advisory data, is free with no rate limits, and supports direct PURL
  queries with batch API.

We initially built a CPE synthesis pipeline (vendor map, NVD API lookup,
cross-ecosystem false positive filtering) to target NVD. This was significant
complexity for the weaker database.

### The pedigree ancestor approach (rejected)

Our first approach kept `pkg:nix/` as the primary PURL and added upstream
PURLs (e.g., `pkg:pypi/django@5.2.11`) as CycloneDX `pedigree.ancestors`.
This is semantically correct — the Nix component IS derived from the upstream
package — but no existing scanner reads `pedigree.ancestors` for vulnerability
matching. Not Grype, not Trivy, not OSV-Scanner, not Dependency-Track.
There is a Dependency-Track discussion from 2022 requesting this; it was
never implemented.

## Decision

**Use upstream ecosystem PURLs as the primary component identifier** when an
upstream ecosystem is detected. Move Nix-specific metadata into
`component.properties` and `pedigree.patches[]`.

### PURL strategy

- When ecosystem is detected: `pkg:pypi/django@5.2.11` (primary PURL)
- When no ecosystem signal: `pkg:nix/openssl@3.6.1` (with CPE from
  `meta.identifiers` for NVD matching)

### Ecosystem detection (3 tiers)

1. **Nix-native signals (99% confidence):** Derivation attributes set by
   build helpers — `meta.isBuildPythonPackage` (pypi), `goModules` (golang),
   `cargoDeps` (cargo), `npmDeps`/`bunDeps` (npm). These are the most
   reliable because they come from the build system itself.

2. **URL heuristics (90-95% confidence):** Source URLs and homepage patterns
   — `files.pythonhosted.org`, `proxy.golang.org`, `crates.io`, etc. Fallback
   for packages where Nix-native signals aren't available.

3. **pypiHints from uv.lock (80% confidence):** Package names listed in the
   Python lockfile. Used for store-path-only packages that lack both Nix-native
   and URL-based signals.

### Nix metadata captured

Rather than losing Nix provenance information, we capture it in standard
CycloneDX fields:

| CycloneDX field | Nix source | Purpose |
|---|---|---|
| `component.properties` nix:storePath | Nix store path | Nix provenance |
| `component.properties` nix:packaged | Always "true" | Identifies Nix-built components |
| `component.properties` nix:maintainer:* | meta.maintainers | Nix packager contact info |
| `pedigree.patches[]` | Nix patches applied | Documents divergence from upstream |
| `externalReferences` RELEASE_NOTES | meta.changelog | Triage aid |
| `evidence.identity` | Detection method | Documents how PURL was determined |
| `vulnerabilities[]` | meta.knownVulnerabilities | Nix-flagged CVEs |

### Component type detection

Components with `meta.mainProgram` (executables like osv-scanner, cosign,
bash) are typed as `application`. All others default to `library`.

### pypiHints (expected to become redundant)

Tier B detection uses a JSON list of package names from `uv.lock` as a
fallback for packages that lack both Nix-native and URL-based signals.
Since uv2nix builds all packages with `buildPythonPackage` (which sets
`meta.isBuildPythonPackage`), Nix-native detection (tier 0) should
eventually handle all these packages, making pypiHints unnecessary. It
is retained as a safety net until end-to-end confirmation in CI.

## Consequences

### Positive

- **Every scanner works out of the box.** 180/207 components in the
  sbomify-app SBOM now use upstream PURLs that Grype, Trivy, OSV-Scanner,
  and Dependency-Track can match directly.

- **5x enrichment improvement.** ecosyste.ms enriched 201/207 components
  (up from 41/207 with `pkg:nix/` PURLs) — descriptions, licenses,
  publishers, repository URLs.

- **Nix patches are documented.** `pedigree.patches[]` lists which patches
  Nix applied, letting a human triage false positives ("this CVE is flagged
  for django but Nix applied a backport patch for it").

### Negative

- **The PURL is a small lie.** `pkg:pypi/django@5.2.11` implies the
  component is the PyPI package, but it's actually a Nix-rebuilt version
  that may have different patches, build flags, or linked libraries. The
  `pedigree.patches` and `nix:packaged` property document this divergence.

- **False positives are possible.** A scanner may flag a CVE that Nix
  already patched. This is the safe direction — false positives (flagged
  but already fixed) are far better than false negatives (real vulnerability
  invisible because scanner can't match `pkg:nix/`).

### Risks

- If an upstream ecosystem changes its registry URL patterns, URL-based
  detection (tier A) could break. Nix-native detection (tier 0) is immune
  to this since it reads build system attributes.
