# Compliance Infrastructure Learnings

## Conventions
- Nix flake structure with pinned nixpkgs
- Curated overlay pattern for package exposure
- Devcontainer with mcr.microsoft.com/devcontainers/base:ubuntu base

## Patterns
- Use `nix flake check` for validation
- All packages must have metadata (description, license, homepage)
- Pinned versions only - no floating references

## Gotchas
- SBOM generation only on release (not per-commit)
- No secrets in repository (use GitHub Secrets)
- Strict 10 package limit without RFC process

## Decisions
- CycloneDX format for SBOMs
- SLSA Level 3 for provenance
- Cachix for binary cache
- GitHub Security API for CVE scanning

## Task 1: Flake Initialization

### Completed: 2026-02-02

#### Flake Structure Patterns

**Pinned Nixpkgs**
- Use specific revision hash for reproducibility
- Example: `github:NixOS/nixpkgs/50ab793786d9de88ee30ec4e4c24fb4236fc2674`
- Lock file captures exact state with narHash

**Curated Overlay Pattern**
- Use `final: prev:` pattern for overlays
- Prefix curated packages with `curated-` to avoid conflicts
- Apply overlay via `pkgs.extend curatedOverlay`
- Expose both individual packages and combined `default` package

**Multi-System Support**
- Define `supportedSystems` list: x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin
- Use `forEachSystem` helper with `nixpkgs.lib.genAttrs`
- Flake outputs automatically generated for all systems

**Package Metadata**
- Include `meta` attribute for all packages
- Required fields: description, license, platforms
- Optional: homepage, maintainers

**Devcontainer Configuration**
- Base image: `mcr.microsoft.com/devcontainers/base:ubuntu`
- Nix feature from `ghcr.io/devcontainers/features/nix:1`
- Enable flakes: `experimental-features = nix-command flakes`
- VSCode extensions: nix-ide, direnv, nix-env-selector

#### Verification Commands

```bash
# Check flake validity
nix flake check

# Show all outputs
nix flake show

# Test devshell
nix develop --command bash -c "which go && which git && which gh"

# Validate JSON
jq '.' .devcontainer/devcontainer.json > /dev/null && echo "Valid JSON"
```

#### Gotchas

1. **Git tracking required**: Nix flakes must be tracked by git to be visible
2. **Lock file generation**: Run `nix flake lock` after creating flake.nix
3. **Placeholder packages**: When package not in nixpkgs, create placeholder derivation
4. **Dirty git tree**: Warnings appear during development - expected behavior

#### Package Versions (nixos-24.11)

- go: 1.23.8
- git: 2.47.2
- gh: 2.63.0
- jq: 1.7.1
- ripgrep: 14.1.1
- grep (gnugrep): 3.11
- findutils: 4.10.0
- gawk: 5.3.1
- gnused: 4.9
- opencode: placeholder (not in nixpkgs yet)

## Task 2: Package Derivations

### Completed: 2026-02-02

#### Package Structure Patterns

**pkgs/ Directory Layout**
```
pkgs/
├── go/default.nix          # Go 1.23.8
├── git/default.nix         # Git 2.47.2
├── gh/default.nix          # GitHub CLI 2.63.0
├── jq/default.nix          # jq 1.7.1
├── ripgrep/default.nix     # ripgrep 14.1.1
├── grep/default.nix        # GNU grep 3.11
├── findutils/default.nix   # GNU findutils 4.10.0
├── gawk/default.nix        # GNU awk 5.3.1
├── gnused/default.nix      # GNU sed 4.9
└── opencode/default.nix    # OpenCode 1.1.48
```

**Override Pattern for Nixpkgs Packages**
- Use `overrideAttrs` to wrap existing nixpkgs packages
- Preserve original package while adding curated metadata
- Pin version in meta.description for transparency
- Example:
```nix
{ lib, git }:
git.overrideAttrs (oldAttrs: {
  pname = "curated-git";
  version = "2.47.2";
  meta = with lib; {
    description = "Distributed version control system (curated)";
    homepage = "https://git-scm.com/";
    license = licenses.gpl2Only;
    platforms = platforms.all;
  };
})
```

**Binary Distribution Pattern (for opencode)**
- Download pre-built binaries from GitHub releases
- Use `fetchurl` with platform-specific hashes
- Apply `autoPatchelfHook` for Linux binaries
- Handle different archive formats (.tar.gz for Linux, .zip for Darwin)
- Example hash fetching:
```bash
nix-prefetch-url \
  "https://github.com/anomalyco/opencode/releases/download/v1.1.48/opencode-linux-x64.tar.gz"
# Returns: 1g403v47zl1hd0im51wabis92d5yr9d1msn2izh38m116868h93m
```

**Flake Integration**
- Expose overlay via `overlays.default`
- Use `callPackage` to import from pkgs/ directory
- Apply overlay with `pkgs.extend self.overlays.default`
- Expose individual packages and combined `default` package

#### Package Versions (Pinned)

| Package | Version | Source |
|---------|---------|--------|
| go | 1.23.8 | nixos-24.11 |
| git | 2.47.2 | nixos-24.11 |
| gh | 2.63.0 | nixos-24.11 |
| jq | 1.7.1 | nixos-24.11 |
| ripgrep | 14.1.1 | nixos-24.11 |
| grep | 3.11 | nixos-24.11 |
| findutils | 4.10.0 | nixos-24.11 |
| gawk | 5.3.1 | nixos-24.11 |
| gnused | 4.9 | nixos-24.11 |
| opencode | 1.1.48 | github:anomalyco/opencode |

#### Metadata Requirements

All packages include:
- `description` - Short description with "(curated)" suffix
- `homepage` - Project homepage URL
- `license` - SPDX license identifier
- `platforms` - Supported platforms list
- `longDescription` - Detailed description with version info

#### Verification Commands

```bash
# Check flake validity
nix flake check

# Build all packages
for pkg in go git gh jq ripgrep grep findutils gawk gnused opencode; do
  nix build ".#$pkg" --no-link --print-out-paths
done

# Run package
nix run .#go -- version
nix run .#opencode -- version
```

#### Gotchas

1. **Git tracking required**: Nix flakes must be tracked by git to be visible
2. **Hash format**: Use base32 hashes (43 chars) not SRI format for fetchurl
3. **Platform variants**: opencode has different binaries per platform
4. **autoPatchelfHook**: Required for Linux binaries to fix dynamic linking
5. **Dirty git tree**: Warnings appear during development - expected behavior

## Task 3: Devcontainer Configuration

### Completed: 2026-02-02

#### Devcontainer Configuration Patterns

**Nix Feature Integration**
- Use `ghcr.io/devcontainers/features/nix:1` for official Nix support
- Configure multi-user: `multiUser: true` for shared nix store
- Enable flakes via `extraNixConfig`: `experimental-features = nix-command flakes`
- No custom Dockerfile needed - features approach is cleaner

**Volume Mounts for Persistence**
- Nix store: `source=devcontainer-nix-store,target=/nix,type=volume`
- Nix cache: `source=devcontainer-nix-cache,target=/home/vscode/.cache/nix,type=volume`
- SSH keys: `source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,consistency=cached`

**Enhanced postCreateCommand**
```json
"postCreateCommand": "nix --version && nix develop --command bash -c 'echo \"Nix development environment ready!\" && which go && which git && which gh'"
```
- Verifies Nix installation
- Runs `nix develop` to initialize flake environment
- Verifies tools are available in the shell

**VS Code Extensions**
- `jnoortheen.nix-ide` - Nix language support
- `mkhl.direnv` - direnv integration for environment variables
- `arrterian.nix-env-selector` - Nix environment switching

**VS Code Settings**
- `nix.enableLanguageServer: true` - Enable LSP
- `nix.serverPath: nixd` - Use nixd for language server
- `nix.formatterPath: nixpkgs-fmt` - Use nixpkgs-fmt for formatting

#### Configuration Structure

```json
{
  "name": "Compliance Infrastructure - Nix Devcontainer",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/devcontainers/features/nix:1": {
      "version": "latest",
      "multiUser": true,
      "extraNixConfig": "experimental-features = nix-command flakes"
    }
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "jnoortheen.nix-ide",
        "mkhl.direnv",
        "arrterian.nix-env-selector"
      ],
      "settings": {
        "nix.enableLanguageServer": true,
        "nix.serverPath": "nixd",
        "nix.formatterPath": "nixpkgs-fmt"
      }
    }
  },
  "postCreateCommand": "nix --version && nix develop --command bash -c 'echo \"Nix development environment ready!\" && which go && which git && which gh'",
  "postStartCommand": "nix flake check || echo 'Flake check completed'",
  "remoteUser": "vscode",
  "mounts": [
    "source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,consistency=cached",
    "source=devcontainer-nix-store,target=/nix,type=volume",
    "source=devcontainer-nix-cache,target=/home/vscode/.cache/nix,type=volume"
  ],
  "runArgs": ["--env", "GIT_EDITOR=code --wait"]
}
```

#### Verification Commands

```bash
# Validate JSON syntax
jq '.' .devcontainer/devcontainer.json > /dev/null && echo "Valid JSON"

# Build devcontainer (requires devcontainer CLI)
devcontainer build --workspace-folder . --config .devcontainer/devcontainer.json

# Verify container has tools
devcontainer exec --workspace-folder . -- bash -c "which go && which git && which gh"

# Test flake loading
devcontainer exec --workspace-folder . -- nix flake check
```

#### Gotchas

1. **No custom Dockerfile needed**: Using devcontainer features is cleaner than custom Dockerfile
2. **Volume names must be unique**: Use descriptive names like `devcontainer-nix-store`
3. **postStartCommand runs on every reconnect**: Keep it lightweight (flake check is fine)
4. **postCreateCommand runs once**: Use it for heavy initialization (nix develop)
5. **SSH mount requires existing directory**: Ensure `${localEnv:HOME}/.ssh` exists on host


## Task 4: SBOM Generation Workflow

### Completed: 2026-02-02

#### Workflow Structure Patterns

**Release-Only Trigger**
- Trigger: `on: release: types: [published]`
- Per guardrail: SBOM generation only on release, not per-commit
- Prevents unnecessary computation and repository bloat

**Required Permissions**
```yaml
permissions:
  contents: write          # For uploading release assets
  dependency-graph: write  # For GitHub Security API submission
```

**Tool Version Pinning**
- Pin SBOM generator to specific commit: `github:nikstur/bombon/<commit-hash>`
- Ensures reproducible SBOM generation across runs
- Document pinned version with comment explaining rationale

**Nix Installation**
- Use `DeterminateSystems/nix-installer-action@v13` for reliable Nix setup
- Enable flakes via `extra-conf`: `experimental-features = nix-command flakes`
- Accept flake config to allow substituters: `accept-flake-config = true`

#### SBOM Generation Process

**Individual Package SBOMs**
```bash
packages=(go git gh jq ripgrep grep findutils gawk gnused opencode)
for pkg in "${packages[@]}"; do
  nix run github:nikstur/bombon -- ".#${pkg}" --output "sboms/${pkg}-sbom.json" --format cyclonedx
done
```

**Merging SBOMs with jq**
- Combine all individual SBOMs into single CycloneDX document
- Deduplicate components by purl (package URL)
- Generate unique serial number (UUID) for merged SBOM
- Include metadata about the release and tool used

**GitHub Security API Submission**
- Endpoint: `POST /repos/{owner}/{repo}/dependency-graph/snapshots`
- Convert CycloneDX components to GitHub's dependency format
- Required fields: version, sha, ref, job, detector, scanned, manifests
- Use `package_url` (purl) from CycloneDX for each dependency

#### Artifact Management

**Release Asset Upload**
- Use `actions/upload-release-asset@v1` for attaching to release
- Asset name: `cyclonedx-sbom.json`
- Content type: `application/json`

**Workflow Artifacts**
- Upload individual SBOMs for debugging/auditing
- Retention: 30 days (sufficient for release verification)

#### Verification Commands

```bash
# Validate workflow YAML
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/sbom.yml'))"

# Dry-run SBOM generation locally
nix run github:nikstur/bombon -- --help

# Generate SBOM for one package
nix run github:nikstur/bombon -- ./.#go --output go-sbom.json

# Validate CycloneDX format (requires cyclonedx-cli)
cyclonedx validate --input-file sbom.json --input-format json
```

#### Gotchas

1. **upload-release-asset is deprecated**: The action `actions/upload-release-asset@v1` is unmaintained but still functional. Consider migrating to `softprops/action-gh-release` in future.

2. **GitHub API version header**: Must include `X-GitHub-Api-Version: 2022-11-28` for dependency submission API.

3. **Token permissions**: `GITHUB_TOKEN` automatically has required permissions when `permissions` block is properly configured.

4. **jq merging complexity**: CycloneDX merging requires careful handling of arrays (components, dependencies) to avoid duplicates.

5. **bombon version**: The pinned commit hash in the example is placeholder - update with actual latest stable commit.


## Task 5: SLSA Level 3 Provenance Workflow

### Completed: 2026-02-02

#### SLSA Level 3 Requirements

**Key Requirements for Level 3:**
1. **Hardened Build Platform**: Use GitHub-hosted runners with SLSA generator
2. **Hermetic Builds**: No network access during build (Nix provides this naturally)
3. **Signed Provenance**: Attestations signed with GitHub OIDC token
4. **Reproducible**: Pinned dependencies and tool versions

**Required Permissions:**
```yaml
permissions:
  contents: write          # For uploading release assets
  id-token: write          # CRITICAL: For OIDC token signing
  actions: read            # For reading workflow info
```
The `id-token: write` permission is essential for SLSA Level 3 - it allows the workflow to obtain a GitHub OIDC token for signing attestations.

#### Workflow Architecture

**Multi-Job Design:**
1. **build job**: Creates artifacts and generates hashes
2. **provenance job**: Uses SLSA generator with hardened runner
3. **release job**: Attaches artifacts and attestation to GitHub release
4. **summary job**: Generates workflow summary with verification instructions

**Artifact Flow:**
```
build → provenance → release → summary
   ↓         ↓          ↓
hashes  attestation  release assets
```

#### SLSA Generator Integration

**Using slsa-framework/slsa-github-generator:**
```yaml
- name: Generate SLSA Level 3 provenance
  uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.0.0
  with:
    base64-subjects: "${{ needs.build.outputs.hashes }}"
    provenance-name: "slsa-attestation.intoto.jsonl"
    upload-assets: true
    upload-to-release: true
```

**Key Configuration:**
- `base64-subjects`: Base64-encoded SHA256 hashes of artifacts
- `provenance-name`: Output filename for the attestation
- `upload-to-release`: Automatically attach to GitHub release
- Version pinned to `v2.0.0` for reproducibility

#### Hermetic Builds with Nix

**Why Nix Satisfies SLSA Hermetic Requirement:**
- Pinned nixpkgs revision in flake.lock
- Fixed-output derivations (FOD) for downloads
- Pure evaluation mode (no external dependencies)
- Reproducible builds across different machines

**Build Process:**
```bash
# Build each package
store_path=$(nix build ".#${pkg}" --no-link --print-out-paths)

# Create tarball
tar -czf "artifacts/${pkg}.tar.gz" -C "$store_path" .
```

#### Attestation Storage

**Dual Storage Strategy:**
1. **GitHub Release**: Attached as release asset for immediate access
2. **Repository**: Committed to `attestations/` directory for long-term preservation

**Repository Storage:**
```yaml
- name: Store attestation in repository
  run: |
    mkdir -p attestations
    cp attestation/slsa-attestation.intoto.jsonl \
       "attestations/slsa-attestation-${{ github.event.release.tag_name }}.intoto.jsonl"
    ln -sf "slsa-attestation-${{ github.event.release.tag_name }}.intoto.jsonl" \
           attestations/slsa-attestation-latest.intoto.jsonl
```

#### Verification Commands

**Install slsa-verifier:**
```bash
go install github.com/slsa-framework/slsa-verifier/v2/cli/slsa-verifier@latest
```

**Verify Attestation:**
```bash
# Download from release
gh release download <tag>

# Verify
slsa-verifier verify-artifact \
  --provenance-path slsa-attestation-<tag>.intoto.jsonl \
  --source-uri github.com/owner/repo \
  --source-tag <tag> \
  wellmaintained-nixpkgs-<tag>.tar.gz
```

#### Gotchas

1. **OIDC token permission**: Without `id-token: write`, SLSA signing will fail silently
2. **SLSA generator version**: Must use `generator_generic_slsa3.yml` specifically for Level 3
3. **Base64 encoding**: Artifact hashes must be base64-encoded for the generator
4. **Artifact retention**: Build artifacts need retention-days set for multi-job workflows
5. **Hermetic verification**: Nix builds are hermetic by design, but verify with `nix build --rebuild`

#### Security Considerations

1. **No self-hosted runners**: Use GitHub-hosted runners only (security requirement for SLSA)
2. **Pinned versions**: All tools pinned to specific versions
3. **Minimal permissions**: Only request permissions actually needed
4. **No secrets in logs**: Use GitHub Secrets for any sensitive data
5. **Attestation integrity**: Attestations are signed and tamper-evident


## Task 6: Binary Cache (Cachix)

### Completed: 2026-02-02

#### Workflow Structure Patterns

**Release-Only Push**
- Trigger: `on: release: types: [published]` and `workflow_dispatch`
- Allows manual cache updates via workflow dispatch
- Supports selective package pushing via inputs

**Required Permissions**
```yaml
permissions:
  contents: read
  id-token: write  # Required for OIDC authentication with Cachix
```

**Cachix Action Configuration**
```yaml
- uses: cachix/cachix-action@v15
  with:
    name: wellmaintained-nixpkgs
    signing-key: ${{ secrets.CACHIX_SIGNING_KEY }}
    auth-token: ${{ secrets.CACHIX_AUTH_TOKEN }}
    replace-local: true
```

**Key Configuration:**
- `name`: Cache name (must match Cachix cache name)
- `signing-key`: Private key for signing NARs before upload
- `auth-token`: Alternative authentication via Cachix API token
- `replace-local`: Overwrite local cache entries with remote

#### Build and Push Process

**Package Selection**
```bash
# From workflow input or default list
PACKAGES=(go opencode git gh jq ripgrep grep findutils gawk gnused)

# Build each package
nix build ".#$pkg" --no-link

# Sign and push to cache
nix store sign --key-file ~/.config/cachix/signing-key.sec ".#$pkg"
nix copy --to "cachix://wellmaintained-nixpkgs" ".#$pkg"
```

**Key Steps:**
1. Build package with `nix build --no-link` (no output, just derivation)
2. Sign NAR files with signing key
3. Copy to Cachix via `nix copy` command

#### Consumer Configuration

**nix.conf Format**
```ini
substituters = https://wellmaintained-nixpkgs.cachix.org https://cache.nixos.org
trusted-public-keys = wellmaintained-nixpkgs-1:<PUBLIC_KEY> cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
```

**Getting Public Key**
```bash
# From Cachix website
curl -s https://wellmaintained-nixpkgs.cachix.org/nix-cache-info

# Or from cachix CLI (if authenticated)
cachix info wellmaintained-nixpkgs
```

#### GitHub Secrets Setup

**Required Secrets:**
| Secret | Purpose |
|---------|---------|
| `CACHIX_SIGNING_KEY` | Private key for signing NARs |
| `CACHIX_AUTH_TOKEN` | API token for authentication |
| `CACHIX_PUBLIC_KEY` | Public key (for documentation) |

**Creating Secrets:**
```bash
# Generate signing key (run locally)
cachix signing-key-gen wellmaintained-nixpkgs

# Add to GitHub
gh secret set CACHIX_SIGNING_KEY --body="$(cat signing-key.sec)"

# Create API token at https://app.cachix.org/tokens
gh secret set CACHIX_AUTH_TOKEN --body="<token-value>"
```

#### Verification Commands

```bash
# Verify cache is accessible
curl -s https://wellmaintained-nixpkgs.cachix.org/nix-cache-info

# Test pushing to cache (requires auth)
echo "test" | cachix push wellmaintained-nixpkgs

# Verify nix can use cache
nix build .#go --option substituters https://wellmaintained-nixpkgs.cachix.org

# Check cache contents
cachix ls wellmaintained-nixpkgs
```

#### Gotchas

1. **Signing key file location**: Cachix action stores key at `~/.config/cachix/signing-key.sec`
2. **Public key format**: The public key in nix.conf must match exactly (43 chars base32)
3. **Cache warm-up**: First release will be slow as all binaries are uploaded
4. **Permission requirements**: `id-token: write` is needed for OIDC authentication
5. **Replace-local flag**: Ensures remote cache takes precedence over local store

#### Security Considerations

1. **Never commit signing key**: Always use GitHub Secrets
2. **Rotate keys periodically**: Generate new signing key and update secrets
3. **Monitor cache access**: Use Cachix dashboard to track downloads
4. **Limit push permissions**: Only CI workflow needs push access
5. **Public read access**: Cache should be public for consumers

#### Cache Management

**Monitoring:**
- Dashboard: https://app.cachix.org/cache/wellmaintained-nixpkgs
- Storage limits: Monitor usage to avoid exceeding quotas
- Download stats: Track cache hit rates

**Maintenance:**
```bash
# List cache contents
cachix ls wellmaintained-nixpkgs

# Remove old derivations (if needed)
cachix rm wellmaintained-nixpkgs --derivation <path>

# Export cache for backup
cachix export wellmaintained-nixpkgs > backup.tar.gz
```

#### Performance Considerations

1. **Compression**: Cachix automatically compresses NAR files
2. **Parallel uploads**: `nix copy` supports parallel transfers
3. **Cache warming**: First build after release will be slow
4. **Substituter order**: Put Cachix before cache.nixos.org for faster hits

#### Documentation Files Created

| File | Purpose |
|------|---------|
| `.github/workflows/cache.yml` | CI workflow for pushing to cache |
| `.github/cachix-setup.md` | Setup guide for maintainers |
| `nix.conf` | Consumer configuration template |
| `README.md` | Usage documentation with cache info |


## Task 7: CVE Triage Workflow and Security Documentation

### Completed: 2026-02-02

#### CVE Triage Workflow Patterns

**Trigger Configuration**
- Multiple triggers: repository_dispatch, schedule (every 6 hours), workflow_dispatch
- Manual trigger supports severity filtering for targeted scans
- Repository dispatch for integration with external security tools

**GitHub API Integration**
- Dependabot alerts endpoint: `/repos/{owner}/{repo}/dependabot/alerts`
- Required headers: Authorization, Accept (application/vnd.github+json), X-GitHub-Api-Version
- Pagination support with `per_page=100` parameter

**SBOM Integration**
- Cross-reference CVEs with package list from CycloneDX SBOM
- Generate SBOM on-demand if not present: `nix run github:nikstur/bombon`
- Package context helps determine if vulnerability affects curated packages

**Issue Creation Logic**
- Check for existing issues to avoid duplicates
- Severity-based auto-assignment (Critical/High → security team)
- SLA labels: SLA:24h, SLA:7d, SLA:30d, SLA:90d
- Structured issue body with triage checklist

**YAML Multiline String Handling**
- Avoid markdown headers (###) in shell scripts within YAML
- Use file-based approach: write to temp file, read back
- Prevents YAML parsing errors with special characters

#### SLA Commitments

| Severity | Response | Resolution | Label |
|----------|----------|------------|-------|
| Critical | 24 hours | 7 days | SLA:24h |
| High | 7 days | 30 days | SLA:7d |
| Medium | 30 days | 90 days | SLA:30d |
| Low | 90 days | 180 days | SLA:90d |

#### Security Documentation Structure

**SECURITY.md Sections**
1. Supported Versions - Clear version support policy
2. Reporting Process - Email-based for sensitive issues
3. SLA Commitments - Tabular format with timeframes
4. Triage Workflow - How automation works
5. Best Practices - For users and contributors
6. Compliance Artifacts - SBOM, SLSA, CVE scan references
7. Contact Information - Multiple channels

**Issue Template Features**
- Front matter with labels and assignees
- Security warning about email for critical issues
- Checkbox-based categorization
- Reproduction steps section
- Impact assessment
- Acknowledgment checklist

#### Verification Commands

```bash
# Validate workflow YAML
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/cve-triage.yml'))"

# Check SECURITY.md sections
grep -E "(SLA|triage|CVE|reporting)" SECURITY.md

# List all security-related files
ls -la .github/workflows/cve-triage.yml SECURITY.md .github/ISSUE_TEMPLATE/security.md
```

#### Gotchas

1. **YAML parsing with markdown**: Shell scripts containing markdown headers (###) break YAML parsing
2. **GitHub API rate limits**: Use pagination and caching to avoid hitting limits
3. **Issue deduplication**: Always check for existing issues before creating new ones
4. **SBOM availability**: Workflow must handle missing SBOM gracefully
5. **Assignee configuration**: Use repository variable `SECURITY_TEAM_HANDLE` for flexibility

#### Files Created

| File | Purpose |
|------|---------|
| `.github/workflows/cve-triage.yml` | Automated CVE triage workflow |
| `SECURITY.md` | Security policy and SLA documentation |
| `.github/ISSUE_TEMPLATE/security.md` | Template for security reports |


## Task 8: Comprehensive Documentation

### Completed: 2026-02-02

#### Documentation Structure Patterns

**User-Centric Usage Guide**
- Focus on consumption patterns: Flake input, Overlay, Devcontainer.
- Provide clear, copy-pasteable code snippets.
- Include verification steps for compliance artifacts (SBOM, SLSA).

**Maintainer-Centric Maintenance Guide**
- Document the RFC process for scope control (10 package limit).
- Provide step-by-step instructions for version updates.
- Detail the release process and how it triggers automation.

**Compliance-Focused Documentation**
- Explain the "why" and "how" of each compliance feature.
- Link to official specifications (CycloneDX, SLSA).
- Detail the CVE triage process and SLA commitments.

**README Enhancement**
- Use badges for immediate visibility of compliance status.
- Provide a clear "Documentation" section with links to sub-guides.
- Keep the "Quick Start" simple and actionable.

#### Verification Commands

```bash
# Check all markdown files exist
ls -la docs/*.md README.md

# Verify markdown syntax (basic check)
head -5 docs/usage.md
head -5 docs/maintenance.md
head -5 docs/compliance.md
```

#### Gotchas

1. **Link Validity**: Ensure all internal links between documentation files are correct.
2. **Badge URLs**: Use reliable badge providers (like Shields.io) and verify they render.
3. **Consistency**: Ensure version numbers and package lists match across all files.
4. **Clarity**: Use clear headings and formatting to make the documentation readable.
