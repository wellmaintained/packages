# Curated Nixpkgs Compliance Infrastructure

## TL;DR

> **Quick Summary**: Create a curated Nix package set for Golang development with SBOMs (CycloneDX), SLSA Level 3 provenance, and GitHub Security CVE integration. Includes opencode AI coding agent, Go toolchain, and essential dev tools packaged as a .devcontainer and Nix flake.
> 
> **Deliverables**: 
> - `flake.nix` with curated overlay (10 packages)
> - `.devcontainer/` configuration for VS Code
> - GitHub Actions workflows for SBOM generation, SLSA provenance, and CVE triage
> - Binary cache configuration
> - Documentation for maintainers and users
> 
> **Estimated Effort**: Medium (3-5 days)
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Package derivations → SBOM workflow → SLSA provenance → CVE triage

---

## Context

### Original Request
Create a curated set of Nixpkgs with comprehensive compliance metadata - SBOMs, SLSA Level 3 provenance, CVE triage & patching SLAs. The goal is for other projects' flakes to refer to this project's curated package set rather than nixos/nixpkgs-unstable, gaining confidence in well-maintained packages with easy compliance integration.

### Scope Decision (Confirmed)
**Initial MVP**: Golang development environment for building opencode agentic coding tool
- 10 curated packages: go (latest), opencode, git, gh, jq, ripgrep, grep, findutils, gawk, gnused
- Delivered as: .devcontainer + Nix flake
- Compliance: CycloneDX SBOMs, SLSA Level 3, GitHub Security CVE scanning
- Trigger: SBOM generation on release only

### Metis Review Findings (Addressed)
**Key Gaps Identified**:
- Need strict 10 package scope limit with formal approval process for additions
- Must pin all tool versions (Go, nixpkgs, bombon) for reproducibility
- Binary cache strategy needs definition (Cachix vs self-hosted)
- CVE triage workflow needs SLA targets and escalation paths
- Multi-architecture support decision needed (x86_64 only vs arm64)

**Guardrails Applied**:
- Scope locked to 10 packages; no additions without formal RFC
- Release-only SBOM generation (not per-commit)
- All secrets via GitHub Secrets (none in repo)
- Pinned nixpkgs revision for reproducibility

---

## Work Objectives

### Core Objective
Create a production-ready curated Nix package set with automated compliance metadata generation, suitable for enterprise use in regulated environments.

### Concrete Deliverables
1. **Package Infrastructure**:
   - `flake.nix` exposing curated overlay and devcontainer
   - 10 package derivations with pinned versions
   - `.devcontainer/devcontainer.json` with Nix support

2. **Compliance Automation**:
   - CycloneDX SBOM generation workflow (release-triggered)
   - GitHub Security SBOM submission integration
   - SLSA Level 3 provenance attestation via GitHub Actions
   - CVE triage workflow with SLA tracking

3. **Distribution**:
   - Binary cache configuration (Cachix or GitHub Packages)
   - Documentation: usage guide, maintenance runbook, security policy

### Definition of Done
- [ ] All 10 packages build successfully via `nix build .#<package>`
- [ ] Devcontainer launches with all tools available
- [ ] Release creates CycloneDX SBOM and submits to GitHub Security
- [ ] SLSA provenance attestation attached to releases
- [ ] CVE triage workflow routes findings to issue queue
- [ ] Documentation complete and reviewed

### Must Have
- 9 specific packages building reproducibly
- CycloneDX SBOM generation on release
- GitHub Security API integration for CVE scanning
- SLSA Level 3 compliant build provenance
- Working .devcontainer configuration

### Must NOT Have (Guardrails)
- No additional packages beyond the 9 without RFC
- No SBOM generation on every commit (release only)
- No secrets or credentials in repository
- No manual steps in release/SBOM workflow
- No support for non-Linux platforms in MVP

---

## Verification Strategy

### Test Infrastructure Assessment
**Infrastructure**: None currently exists in this repo (greenfield project)

**Test Strategy**: Manual verification only (no test framework needed for infrastructure project)

**Verification Approach**: Each TODO includes automated verification commands that can be run via bash tool:
- Nix builds (`nix build`, `nix flake check`)
- SBOM validation (schema validation via tools)
- API testing (curl commands for GitHub Security)
- Container testing (devcontainer up/verification)

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation - Can Start Immediately):
├── Task 1: Create flake.nix structure with curated overlay
├── Task 2: Implement 10 package derivations
└── Task 3: Create .devcontainer configuration

Wave 2 (Compliance - After Wave 1):
├── Task 4: Create SBOM generation workflow
├── Task 5: Implement SLSA Level 3 provenance workflow
└── Task 6: Set up binary cache (Cachix)

Wave 3 (Integration - After Wave 2):
├── Task 7: Create CVE triage workflow and documentation
└── Task 8: Create comprehensive documentation

Critical Path: Task 1 → Task 2 → Task 4 → Task 7
Parallel Speedup: ~35% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2, 3 | None |
| 2 | 1 | 4, 5, 6 | 3 |
| 3 | None | 7 | 1, 2 |
| 4 | 2 | 7 | 5, 6 |
| 5 | 2 | 7 | 4, 6 |
| 6 | None | None | 4, 5 |
| 7 | 3, 4, 5 | 8 | None |
| 8 | 7 | None | None |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Approach |
|------|-------|---------------------|
| 1 | 1, 2, 3 | Sequential - foundation must be solid |
| 2 | 4, 5, 6 | Parallel - independent compliance features |
| 3 | 7, 8 | Sequential - integration and docs |

---

## TODOs

- [ ] 1. Create flake.nix with curated overlay structure

  **What to do**:
  - Create `flake.nix` defining inputs (nixpkgs pinned to specific revision)
  - Define curated overlay that exposes 10 packages
  - Set up flake outputs: `packages`, `devShells`, `overlays`
  - Create `.devcontainer/` directory structure
  - Configure `devcontainer.json` with Nix support using mcr.microsoft.com/devcontainers/base:ubuntu
  
  **Must NOT do**:
  - Don't add packages beyond the 9 specified
  - Don't use floating nixpkgs references (must pin)
  - Don't include experimental features without flag
  
  **Recommended Agent Profile**:
  - **Category**: `unspecified-high` - Nix-specific knowledge required
  - **Skills**: None available match Nix domain
  - **Rationale**: This requires deep Nix expertise for flake structure, overlays, and devcontainer integration. Standard agent without specific Nix skills can handle with careful reference checking.
  
  **Parallelization**:
  - **Can Run In Parallel**: NO (foundation task)
  - **Blocks**: Task 2, Task 3
  
  **References**:
  - `github:xtruder/nix-devcontainer` - Devcontainer Nix pattern
  - `github:nixpkgs-wayland/nixpkgs-wayland` - Curated overlay example
  - NixOS Wiki "Overlays" - Overlay structure documentation
  - `github:hellodword/devcontainers.nix` - Devcontainer patterns
  
  **Acceptance Criteria**:
  - [ ] `nix flake check` passes without errors
  - [ ] `nix flake show` displays 10 curated packages
  - [ ] `nix develop` enters shell with all tools available
  - [ ] `.devcontainer/devcontainer.json` exists and is valid JSON
  
  **Automated Verification**:
  ```bash
  # Verify flake structure
  nix flake check
  
  # Verify packages are exposed
  nix flake show | grep -E "(go|opencode|git|gh|jq|ripgrep|gawk|gnused|findutils|grep)"
  
  # Verify devshell works
  nix develop --command bash -c "which go && which git && which gh"
  
  # Verify devcontainer config is valid
  jq '.' .devcontainer/devcontainer.json > /dev/null && echo "Valid JSON"
  ```
  
  **Commit**: YES
  - Message: `feat(flake): initialize curated package overlay with 10 packages`
  - Files: `flake.nix`, `flake.lock`, `.devcontainer/devcontainer.json`
  - Pre-commit: `nix flake check`

---

- [ ] 2. Implement 10 package derivations

  **What to do**:
  - Create `pkgs/` directory with package definitions
  - Implement each package as overlay or direct derivation:
    1. `go` - Latest Go compiler (1.23+) from pinned nixpkgs
    2. `opencode` - Build from source or use latest release
    3. `git` - Git version control
    4. `gh` - GitHub CLI
    5. `jq` - JSON processor
    6. `ripgrep` - Fast grep alternative
    7. `grep` - GNU grep
    8. `findutils` - GNU find
    9. `gawk` - GNU awk
    10. `gnused` - GNU sed
  - Pin specific versions in overlay (don't use nixpkgs defaults blindly)
  - Add package metadata (description, license, homepage)
  
  **Must NOT do**:
  - Don't add extra packages not in the list
  - Don't use floating versions - pin exact package versions
  - Don't skip metadata (required for SBOM generation)
  
  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Rationale**: Requires Nix derivation writing, understanding of nixpkgs structure
  
  **Parallelization**:
  - **Can Run In Parallel**: YES with Task 3
  - **Blocked By**: Task 1
  - **Blocks**: Task 4, 5, 6
  
  **References**:
  - `github:opencode-ai/opencode` - Source for opencode package
  - `nixpkgs/pkgs/development/compilers/go/` - Go package pattern
  - `nixpkgs/pkgs/applications/versioning/git/` - Git package pattern
  
  **Acceptance Criteria**:
  - [ ] All 10 packages build: `nix build .#{go,opencode,git,gh,jq,ripgrep,grep,findutils,gawk,gnused}`
  - [ ] Each package has metadata: description, license, homepage
  - [ ] Packages work in isolation: `nix run .#go -- version`
  
  **Automated Verification**:
  ```bash
  # Build all packages
  for pkg in go opencode git gh jq ripgrep grep findutils gawk gnused; do
    nix build ".#$pkg" --no-link --print-out-paths
  done
  
  # Verify go works
  nix run .#go -- version | grep "go version"
  
  # Verify opencode binary exists (if building from source)
  nix build .#opencode --no-link --print-out-paths | xargs -I{} ls {}/bin/
  ```
  
  **Commit**: YES
  - Message: `feat(packages): add 10 curated package derivations`
  - Files: `pkgs/*/default.nix`, overlay integration
  - Pre-commit: All packages build successfully

---

- [ ] 3. Create .devcontainer configuration

  **What to do**:
  - Create `.devcontainer/devcontainer.json` with:
    - Base image: `mcr.microsoft.com/devcontainers/base:ubuntu`
    - Nix package manager installation
    - Flake initialization on container start
    - VS Code extensions for Nix
  - Create `.devcontainer/Dockerfile` if needed for custom setup
  - Add `postCreateCommand` to run `nix develop` automatically
  - Configure volume mounts for Nix store persistence
  
  **Must NOT do**:
  - Don't use non-Linux base images (MVP is Linux-only)
  - Don't require manual nix installation steps
  - Don't mount sensitive host paths
  
  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
  - **Rationale**: Standard devcontainer configuration, well-documented patterns
  
  **Parallelization**:
  - **Can Run In Parallel**: YES with Task 2
  - **Blocked By**: Task 1
  - **Blocks**: Task 7 (CVE triage needs working devcontainer for testing)
  
  **References**:
  - `github:xtruder/nix-devcontainer` - Complete Nix devcontainer example
  - VS Code Devcontainer specification documentation
  - `github:hellodword/devcontainers.nix` - Various Nix devcontainer patterns
  
  **Acceptance Criteria**:
  - [ ] Devcontainer builds successfully
  - [ ] All 9 tools available in container shell
  - [ ] Nix flake loads automatically on startup
  
  **Automated Verification**:
  ```bash
  # Validate devcontainer.json syntax
  jq '.' .devcontainer/devcontainer.json > /dev/null
  
  # Build devcontainer (requires devcontainer CLI)
  devcontainer build --workspace-folder . --config .devcontainer/devcontainer.json
  
  # Verify container has tools (after running)
  devcontainer exec --workspace-folder . -- bash -c "which go && which opencode && which git"
  ```
  
  **Commit**: YES (grouped with Task 1 if done together)
  - Message: `feat(devcontainer): add VS Code devcontainer configuration`
  - Files: `.devcontainer/devcontainer.json`, `.devcontainer/Dockerfile` (if needed)
  - Pre-commit: JSON validation passes

---

- [ ] 4. Create SBOM generation workflow

  **What to do**:
  - Create `.github/workflows/sbom.yml` workflow
  - Trigger: Release published (`on: release: types: [published]`)
  - Steps:
    1. Checkout code
    2. Install Nix with flakes support
    3. Install bombon or nix2sbom tool
    4. Generate CycloneDX SBOM for all 10 packages
    5. Merge SBOMs into single document
    6. Upload as release artifact
    7. Submit to GitHub Security API
  - Configure GitHub token for Security API access
  
  **Must NOT do**:
  - Don't trigger on every push (release only per guardrail)
  - Don't commit SBOMs to repo (generate on demand)
  - Don't use floating versions of SBOM tools
  
  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Rationale**: Requires GitHub Actions expertise, API integration, SBOM tooling
  
  **Parallelization**:
  - **Can Run In Parallel**: YES with Task 5, 6
  - **Blocked By**: Task 2 (packages must exist)
  - **Blocks**: Task 7
  
  **References**:
  - `github:nikstur/bombon` - Nix CycloneDX generator
  - `github:louib/nix2sbom` - Alternative SBOM generator
  - GitHub Docs: "Using the dependency submission API"
  - GitHub Action: `spdx-dependency-submission-action` (for reference)
  
  **Acceptance Criteria**:
  - [ ] Workflow triggers on release
  - [ ] Generates valid CycloneDX SBOM
  - [ ] Successfully submits to GitHub Security API
  - [ ] SBOM attached as release artifact
  
  **Automated Verification**:
  ```bash
  # Dry-run SBOM generation locally
  nix run github:nikstur/bombon -- --help
  
  # Generate SBOM for one package
  nix run github:nikstur/bombon -- ./.#go --output go-sbom.json
  
  # Validate CycloneDX format
  cyclonedx validate --input-file go-sbom.json --input-format json
  
  # Test GitHub API submission (dry run)
  curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/repos/$OWNER/$REPO/dependency-graph/snapshots \
    -d @test-sbom.json
  ```
  
  **Commit**: YES
  - Message: `feat(ci): add CycloneDX SBOM generation workflow`
  - Files: `.github/workflows/sbom.yml`
  - Pre-commit: Workflow YAML syntax valid

---

- [ ] 5. Implement SLSA Level 3 provenance workflow

  **What to do**:
  - Create `.github/workflows/provenance.yml`
  - Use SLSA GitHub Generator (official Google/OpenSSF tool)
  - Trigger: Release published
  - Configure for Level 3 compliance:
    - Hardened GitHub-hosted runner
    - No network access during build (Nix hermetic builds)
    - Signed provenance attestation
  - Attach attestation to GitHub release
  - Store attestation in repository for verification
  
  **Must NOT do**:
  - Don't use self-hosted runners (security risk for SLSA)
  - Don't skip attestation signing
  - Don't use non-hermetic builds
  
  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Rationale**: Deep security/compliance knowledge needed for SLSA Level 3
  
  **Parallelization**:
  - **Can Run In Parallel**: YES with Task 4, 6
  - **Blocked By**: Task 2
  - **Blocks**: Task 7
  
  **References**:
  - `slsa-framework/slsa-github-generator` - Official SLSA generator
  - SLSA.dev specification Level 3 requirements
  - GitHub Docs: "Using artifact attestations"
  
  **Acceptance Criteria**:
  - [ ] Workflow generates SLSA attestation on release
  - [ ] Attestation signed with GitHub OIDC token
  - [ ] Attestation attached to release artifacts
  - [ ] Can verify attestation: `slsa-verifier verify-artifact`
  
  **Automated Verification**:
  ```bash
  # Verify workflow syntax
  gh workflow view provenance --yaml
  
  # After release, verify attestation exists
  gh release view <tag> --json assets | jq '.assets[] | select(.name | contains("attestation"))'
  
  # Verify with slsa-verifier (install first)
  slsa-verifier verify-artifact --provenance-path attestation.json \
    --source-uri github.com/$OWNER/$REPO \
    --source-tag <tag> \
    artifact.tar.gz
  ```
  
  **Commit**: YES
  - Message: `feat(security): add SLSA Level 3 provenance workflow`
  - Files: `.github/workflows/provenance.yml`
  - Pre-commit: Workflow YAML valid

---

- [ ] 6. Set up binary cache (Cachix)

  **What to do**:
  - Sign up for Cachix account (or use GitHub Packages)
  - Create cache: `wellmaintained-nixpkgs` (or similar)
  - Generate signing key and add to GitHub Secrets (`CACHIX_SIGNING_KEY`)
  - Create `.github/workflows/cache.yml` to push builds to cache
  - Configure `nix.conf` for substituters in devcontainer
  - Document cache usage for consumers
  
  **Must NOT do**:
  - Don't commit signing key to repo (use GitHub Secrets)
  - Don't push unauthenticated to public cache
  - Don't skip cache documentation
  
  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
  - **Rationale**: Infrastructure setup, straightforward configuration
  
  **Parallelization**:
  - **Can Run In Parallel**: YES with Task 4, 5
  - **Blocked By**: None (can start immediately)
  - **Blocks**: None (enhancement, not blocker)
  
  **References**:
  - Cachix documentation: Getting started guide
  - `cachix/cachix-action` - GitHub Action for Cachix
  - Nix manual: Binary cache configuration
  
  **Acceptance Criteria**:
  - [ ] Cachix cache created and configured
  - [ ] GitHub Secret `CACHIX_SIGNING_KEY` set
  - [ ] Workflow pushes successful builds to cache
  - [ ] Cache documented in README
  
  **Automated Verification**:
  ```bash
  # Verify cache is accessible
  curl -s https://wellmaintained.cachix.org/nix-cache-info
  
  # Test pushing to cache (requires auth)
  echo "test" | cachix push wellmaintained
  
  # Verify nix can use cache
  nix build .#go --option substituters https://wellmaintained.cachix.org
  ```
  
  **Commit**: YES
  - Message: `feat(infra): configure Cachix binary cache`
  - Files: `.github/workflows/cache.yml`, `nix.conf` (if added)
  - Pre-commit: Cache configuration valid

---

- [ ] 7. Create CVE triage workflow and documentation

  **What to do**:
  - Create `.github/workflows/cve-triage.yml`
  - Trigger: GitHub Security alert created (`on: security_advisory` or scheduled)
  - Workflow steps:
    1. Query GitHub Security API for open alerts
    2. Parse affected packages from SBOM
    3. Create GitHub Issues for unpatched CVEs
    4. Auto-assign based on severity (Critical/High → security team)
    5. Add SLA labels (24h, 7d, 30d based on severity)
  - Create `SECURITY.md` with:
    - CVE reporting process
    - SLA commitments (Critical: 24h, High: 7d, Medium: 30d)
    - Triage workflow description
    - Contact information
  - Create issue templates for CVE reports
  
  **Must NOT do**:
  - Don't auto-close CVEs without human review
  - Don't skip SLA documentation
  - Don't use generic issue templates for security
  
  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Rationale**: Security workflow, SLA definitions, requires careful process design
  
  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on 3, 4, 5)
  - **Blocked By**: Task 3 (devcontainer for testing), Task 4 (SBOM for CVE context), Task 5 (security workflow)
  - **Blocks**: Task 8
  
  **References**:
  - GitHub Docs: "Security advisories" and "Dependabot alerts"
  - `github:renovatebot/renovate` - CVE automation patterns
  - `SECURITY.md` templates from major projects (Kubernetes, Node.js)
  
  **Acceptance Criteria**:
  - [ ] CVE triage workflow exists and runs on trigger
  - [ ] SECURITY.md with SLA commitments
  - [ ] Issue templates for security reports
  - [ ] Workflow creates issues for security alerts
  
  **Automated Verification**:
  ```bash
  # Verify workflow syntax
  gh workflow view cve-triage --yaml
  
  # List security alerts via API
  curl -s -H "Authorization: token $GITHUB_TOKEN" \
    https://api.github.com/repos/$OWNER/$REPO/security-advisories
  
  # Verify SECURITY.md exists and has required sections
  grep -E "(SLA|triage|CVE|reporting)" SECURITY.md
  
  # Dry-run triage workflow
  act -j triage -e test-security-event.json
  ```
  
  **Commit**: YES
  - Message: `feat(security): add CVE triage workflow and security policy`
  - Files: `.github/workflows/cve-triage.yml`, `SECURITY.md`, `.github/ISSUE_TEMPLATE/security.md`
  - Pre-commit: Workflow YAML valid, SECURITY.md renders correctly

---

- [ ] 8. Create comprehensive documentation

  **What to do**:
  - Update `README.md`:
    - Project overview and compliance features
    - Usage instructions (flake input, devcontainer)
    - Package list with versions
    - SBOM and SLSA badge/links
  - Create `docs/usage.md`:
    - How to consume as flake input
    - How to use devcontainer
    - How to verify SBOMs and provenance
  - Create `docs/maintenance.md`:
    - How to add new packages (RFC process)
    - How to update package versions
    - Release process
  - Create `docs/compliance.md`:
    - SBOM generation details
    - SLSA Level 3 implementation
    - CVE triage process
    - Audit procedures
  - Add badges: SLSA Level 3, GitHub Security, Cachix
  
  **Must NOT do**:
  - Don't leave TODOs in documentation
  - Don't skip verification instructions
  - Don't document non-existent features
  
  **Recommended Agent Profile**:
  - **Category**: `writing`
  - **Rationale**: Documentation writing, technical prose
  
  **Parallelization**:
  - **Can Run In Parallel**: NO (final integration task)
  - **Blocked By**: Task 7
  - **Blocks**: None
  
  **References**:
  - `github:slsa-framework/slsa` - SLSA documentation patterns
  - CycloneDX specification documentation
  - NixOS Wiki - Flake documentation examples
  
  **Acceptance Criteria**:
  - [ ] README.md explains project and usage
  - [ ] docs/ contains usage, maintenance, compliance guides
  - [ ] All documentation links work
  - [ ] Badges display correctly
  
  **Automated Verification**:
  ```bash
  # Check all markdown files are valid
  find docs -name "*.md" -exec markdownlint {} \;
  
  # Verify internal links work (using lychee or similar)
  lychee README.md docs/
  
  # Verify code blocks in docs work
  grep -A5 '```bash' docs/usage.md | bash -n
  ```
  
  **Commit**: YES
  - Message: `docs: add comprehensive documentation`
  - Files: `README.md`, `docs/*.md`
  - Pre-commit: Markdown linting passes

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(flake): initialize curated package overlay` | `flake.nix`, `flake.lock`, `.devcontainer/devcontainer.json` | `nix flake check` |
| 2 | `feat(packages): add 10 curated package derivations` | `pkgs/` | All packages build |
| 3 | `feat(devcontainer): add VS Code devcontainer` | `.devcontainer/` | Container builds |
| 4 | `feat(ci): add CycloneDX SBOM generation workflow` | `.github/workflows/sbom.yml` | YAML valid |
| 5 | `feat(security): add SLSA Level 3 provenance workflow` | `.github/workflows/provenance.yml` | YAML valid |
| 6 | `feat(infra): configure Cachix binary cache` | `.github/workflows/cache.yml` | Cache accessible |
| 7 | `feat(security): add CVE triage workflow and security policy` | `.github/workflows/cve-triage.yml`, `SECURITY.md` | Workflow valid |
| 8 | `docs: add comprehensive documentation` | `README.md`, `docs/` | Markdown lint |

---

## Success Criteria

### Verification Commands

**Post-Implementation Verification**:
```bash
# 1. Verify flake works
nix flake check

# 2. Verify all packages build
nix build .#{go,opencode,git,gh,jq,ripgrep,grep,findutils,gawk,gnused}

# 3. Verify devcontainer
jq '.' .devcontainer/devcontainer.json
devcontainer build --workspace-folder .

# 4. Verify SBOM can be generated
nix run github:nikstur/bombon -- ./.#go --output /tmp/test-sbom.json
cyclonedx validate --input-file /tmp/test-sbom.json

# 5. Verify workflows exist
ls -la .github/workflows/

# 6. Verify documentation
ls -la docs/
grep -i "slsa\|sbom\|cve" README.md
```

### Final Checklist
- [ ] All 10 packages build successfully via `nix build`
- [ ] Devcontainer configuration valid and builds
- [ ] SBOM generation workflow exists (release-triggered)
- [ ] SLSA provenance workflow configured for Level 3
- [ ] CVE triage workflow with SLA documentation
- [ ] Binary cache configured and accessible
- [ ] Documentation complete (README, docs/)
- [ ] No secrets in repository (all via GitHub Secrets)
- [ ] All 10 packages are strictly limited (no scope creep)

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| SBOM tool (bombon) doesn't support our use case | High | Have fallback: nix2sbom or custom derivation walker |
| GitHub Security API changes/breaks | Medium | Version API calls, monitor GitHub changelog |
| SLSA Level 3 too complex for initial release | Medium | Start with Level 2, iterate to Level 3 |
| Multi-arch support needed (arm64) | Low | Document x86_64-only for MVP, add arm64 later |
| Package version conflicts | Low | Pin all versions, test builds in CI |
| Binary cache performance issues | Low | Monitor cache hits, optimize as needed |

---

## Notes

### Decisions Made
- **SBOM Format**: CycloneDX (user choice)
- **SLSA Level**: Level 3 (user choice, achievable with GitHub Actions)
- **CVE Scanning**: GitHub Security with dependency submission API
- **Trigger**: Release-only (not continuous)
- **Scope**: Strict 10 packages with RFC process for additions

### Future Enhancements (Out of Scope)
- SPDX format support in addition to CycloneDX
- Continuous scanning (on every nixpkgs update)
- Self-hosted binary cache
- macOS/Windows devcontainer support
- Additional package categories (Python, Node.js, etc.)
- Automated CVE patching via Renovate

---

*Plan generated by Prometheus | Metis review incorporated | Ready for execution*
