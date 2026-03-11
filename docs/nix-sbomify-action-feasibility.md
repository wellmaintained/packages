# Feasibility Assessment: Nix Support for sbomify-action

## Summary

Adding Nix SBOM generation to sbomify-action is **feasible and well-suited to the existing architecture**. The action has a clean plugin-based generator system where new generators implement a 5-method Protocol interface. Multiple mature Nix SBOM tools exist (bombon, sbomnix, nix2sbom) that could serve as the underlying engine. The main challenge is that Nix requires `nix` to be installed in the action's Docker container, and the Nix PURL type is not yet standardized — but neither is a blocker.

**Recommended approach:** Add a native Nix generator that shells out to **bombon** (for CycloneDX) or **sbomnix** (for both CycloneDX and SPDX), triggered by the presence of `flake.lock`.

**Effort estimate:** Medium — 2-4 days of implementation work, plus testing and upstream PR review.

---

## sbomify-action Architecture

### Generator Plugin System

sbomify-action uses an orchestrator pattern with a generator registry:

1. `GeneratorOrchestrator` receives a generation request (lockfile path + desired format)
2. Queries `GeneratorRegistry` for compatible generators, sorted by priority
3. Tries generators in priority order until one succeeds
4. Output is validated against JSON schema and sanitized

Each generator implements:
- `name: str` — display name
- `command: str` — CLI tool to check availability
- `priority: int` — lower = tried first (10=native, 20=cdxgen, 30=trivy, 35=syft)
- `supported_formats: List[FormatVersion]` — format/version combos
- `supports(input) -> bool` — can this generator handle this input?
- `generate(input) -> GenerationResult` — execute and return result

### Existing Generators (8 total)

| Priority | Generator | Scope |
|----------|-----------|-------|
| 10 | CycloneDXPyGenerator | Python lockfiles |
| 10 | CycloneDXCargoGenerator | Cargo.lock |
| 20 | CdxgenFsGenerator | 13+ ecosystems |
| 20 | CdxgenImageGenerator | Docker images |
| 30 | TrivyFsGenerator | Filesystem scan |
| 30 | TrivyImageGenerator | Docker images |
| 35 | SyftFsGenerator | Filesystem scan |
| 35 | SyftImageGenerator | Docker images |

### Current Nix Support

**None.** No Nix generator exists. No open issues requesting it. The generic scanners (Trivy, Syft, cdxgen) do not recognize `flake.lock` or Nix store paths.

---

## Nix SBOM Tool Landscape

### Mature Options

| Tool | Output Format | Approach | Maturity |
|------|--------------|----------|----------|
| **bombon** | CycloneDX 1.5 | Nix expression level (.nix) | Production — v0.4.0, 116 stars, active |
| **sbomnix** | CycloneDX + SPDX | Derivation or output path | Production — TIIUAE, Apache 2.0 |
| **nix2sbom** | CycloneDX 1.4, SPDX 2.3 | Derivation level (.drv) | Usable — MIT, less active |
| **genealogos** | CycloneDX + HTML | nixpkgs or flake packages | Funded (NGI0), active |

### Key Differences

- **bombon** works at the Nix expression level, accessing `meta.license`, `meta.version` etc. — richer metadata than derivation-level tools. Outputs CycloneDX only. Requires evaluating the flake.
- **sbomnix** works at derivation or store path level, supports both CycloneDX and SPDX, includes vulnerability scanning (vulnxscan) and dependency graphing. Requires building to get runtime deps.
- **nix2sbom** is simpler, derivation-level only, supports both formats but less actively maintained.

### Generic Scanners and Nix

- **Trivy:** No `flake.lock` support. GitHub issue exists but unimplemented.
- **Syft:** Nix not listed among 40+ supported ecosystems.
- **cdxgen:** Available as Nix package but no Nix-native analysis.
- **Grype:** Can scan Nix-generated SBOMs but doesn't recognize Nix PURLs.

---

## Recommended Approach

### Option A: Shell out to bombon (Recommended)

Create a `NixBombonGenerator` that:
1. Detects `flake.lock` in `supports()`
2. Invokes bombon's Nix-based build to produce a CycloneDX JSON SBOM
3. Returns the result for validation and enrichment

**Pros:**
- Best metadata quality (expression-level access to meta attributes)
- CycloneDX 1.5 compliance (aligns with TR-03183, EO 14028)
- Most actively maintained Nix SBOM tool
- Already used in our packages repo CI

**Cons:**
- CycloneDX only (no SPDX output)
- Requires Nix in the Docker container
- Requires evaluating the flake (not just parsing flake.lock)

### Option B: Shell out to sbomnix

Create a `NixSbomnixGenerator` that invokes sbomnix.

**Pros:**
- Both CycloneDX and SPDX output
- Can work from derivation path without full evaluation
- Includes vulnerability scanning capability

**Cons:**
- Requires building the target for runtime dependency analysis
- Heavier dependency footprint
- Less metadata richness than bombon

### Option C: Parse flake.lock directly (Python-native)

Write a Python parser that reads `flake.lock` JSON and constructs an SBOM using `cyclonedx-python-lib`.

**Pros:**
- No Nix installation required
- Lightweight, fast
- No external tool dependency

**Cons:**
- `flake.lock` only captures direct flake inputs, not the transitive dependency closure
- Missing metadata (versions, licenses) that only Nix evaluation can provide
- Would produce a shallow, incomplete SBOM
- **Not recommended** — the resulting SBOM would be too incomplete to be useful

### Recommendation

**Option A (bombon)** for CycloneDX output. If SPDX support is also needed, add Option B (sbomnix) as a secondary generator at a lower priority.

---

## Implementation Sketch

### New File: `sbomify_action/_generation/generators/nix.py`

```python
class NixBombonGenerator:
    name = "Nix (bombon)"
    command = "nix"  # bombon is invoked via nix build
    priority = 10    # Native generator, same tier as Cargo/Python
    supported_formats = [
        FormatVersion("cyclonedx", ("1.5",), "1.5")
    ]

    def supports(self, input: GenerationInput) -> bool:
        return (input.is_lock_file
            and input.lock_file_name == "flake.lock"
            and input.format == "cyclonedx"
            and input.spec_version in ("1.5",))

    def generate(self, input: GenerationInput) -> GenerationResult:
        # 1. Find flake.nix directory (parent of flake.lock)
        # 2. Run: nix build .#sbom (or bombon's buildBom)
        # 3. Copy result to output path
        # 4. Return GenerationResult
```

### Registration

Add to `create_default_registry()` in `generators/__init__.py`.

### Docker Container Changes

The sbomify-action Dockerfile would need Nix installed. Options:
- Use the Determinate Systems Nix installer (single curl command)
- Or: detect if `nix` is available and skip the generator if not (graceful degradation)

### Enrichment

The existing enrichment pipeline won't have Nix-specific enrichers (no crates.io/PyPI equivalent for nixpkgs). However:
- bombon already embeds license and version metadata from `meta` attributes
- The deps.dev aggregator may resolve some upstream packages
- A future nixpkgs-specific enricher could be added

---

## Key Challenges

### 1. Nix Installation in Docker Container
The sbomify-action Docker image currently bundles Trivy, Syft, cdxgen, cargo-cyclonedx, and cyclonedx-py. Adding Nix increases image size significantly (~300MB+). Mitigation: make it optional or use a separate "nix-enabled" image variant.

### 2. PURL Specification Gap
Nix is not yet a recognized package type in the PURL spec (open issue #149 in package-url/purl-spec). bombon uses `pkg:nix/...` but standard vulnerability scanners won't match these. This is a known ecosystem-wide problem, not specific to sbomify-action.

### 3. Flake Evaluation Time
bombon needs to evaluate the Nix flake to extract metadata, which can take 10-60 seconds depending on complexity. This is slower than parsing a lockfile but acceptable for CI.

### 4. Nix Store State
bombon may need to fetch/build some derivations during evaluation. In a clean CI environment, this could add significant time on first run. Caching helps on subsequent runs.

### 5. Vendored Language Dependencies
Nix packages that vendor Rust/Go/Python dependencies won't have those deps in the Nix dependency tree. bombon has `bombonVendoredSbom` support for this, but it requires the package to opt in.

---

## Effort Estimate

| Task | Effort |
|------|--------|
| Implement NixBombonGenerator | 1 day |
| Add Nix to Docker image (or make optional) | 0.5 day |
| Integration tests | 0.5 day |
| Documentation | 0.5 day |
| Upstream PR review/iteration | 1-2 days |
| **Total** | **3-5 days** |

---

## Blockers

- **None that prevent starting.** The architecture is ready, bombon is mature, and the generator pattern is well-established.
- The PURL gap is a known ecosystem issue that doesn't block SBOM generation — it affects downstream vulnerability scanning, which is out of scope for the generator.
- Docker image size is a packaging concern, not a technical blocker. The graceful degradation pattern (skip if nix not available) means the generator can land without forcing Nix into the default image.

---

## Conclusion

This is a good contribution opportunity. sbomify-action's plugin architecture makes adding new generators straightforward, bombon is the right tool for the job, and there's no competing effort (no open issues or PRs for Nix support). The main decision is whether to bundle Nix in the default Docker image or make it an optional/separate image.
