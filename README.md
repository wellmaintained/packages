# wellmaintained-nixpkgs

[![SLSA Level 3](https://img.shields.io/badge/SLSA-Level%203-blue)](https://slsa.dev)
[![GitHub Security](https://img.shields.io/badge/GitHub-Security-green)](https://github.com/wellmaintained/wellmaintained-nixpkgs/security)
[![Cachix Cache](https://img.shields.io/badge/Cachix-wellmaintained--nixpkgs-orange)](https://wellmaintained-nixpkgs.cachix.org)

Curated Nix package set with compliance automation (SBOMs, SLSA provenance, CVE triage).

## Documentation

- [Usage Guide](docs/usage.md) - How to consume this project
- [Maintenance Guide](docs/maintenance.md) - How to maintain and update packages
- [Compliance Documentation](docs/compliance.md) - Details on SBOM, SLSA, and CVE triage
- [Security Policy](SECURITY.md) - CVE reporting and SLAs

## Features

- **10 Curated Packages**: go, opencode, git, gh, jq, ripgrep, grep, findutils, gawk, gnused
- **CycloneDX SBOMs**: Generated on release via GitHub Actions
- **SLSA Level 3 Provenance**: Signed attestations for all releases
- **CVE Triage**: Automated security advisory processing with SLAs
- **Binary Cache**: Pre-built binaries available via Cachix

## Quick Start

```bash
# Clone and enter directory
git clone https://github.com/wellmaintained/nixpkgs.git
cd nixpkgs

# Enter development shell
nix develop

# Build a package
nix build .#go

# Run a package
nix run .#opencode -- --help
```

## Using as a Flake Input

Add to your `flake.nix`:

```nix
{
  inputs.wellmaintained-nixpkgs.url = "github:wellmaintained/nixpkgs";

  outputs = { self, wellmaintained-nixpkgs }: {
    devShells.${system}.default = wellmaintained-nixpkgs.devShells.${system}.default;
  };
}
```

## Binary Cache

Pre-built binaries are available via [Cachix](https://cachix.org). Configure your Nix to use the cache:

### Configuration

Add to `~/.config/nix/nix.conf` or `/etc/nix/nix.conf`:

```ini
substituters = https://wellmaintained-nixpkgs.cachix.org https://cache.nixos.org
trusted-public-keys = wellmaintained-nixpkgs-1:<PUBLIC_KEY> cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
```

Get the public key from: https://wellmaintained-nixpkgs.cachix.org

### Verify Cache Access

```bash
# Check cache is reachable
curl -s https://wellmaintained-nixpkgs.cachix.org/nix-cache-info

# Build with cache (should be fast if cached)
nix build .#go --option substituters https://wellmaintained-nixpkgs.cachix.org
```

## Packages

| Package | Version | Description |
|---------|---------|-------------|
| go | 1.23.8 | Go programming language |
| opencode | 1.1.48 | AI coding assistant |
| git | 2.47.2 | Version control |
| gh | 2.63.0 | GitHub CLI |
| jq | 1.7.1 | JSON processor |
| ripgrep | 14.1.1 | Fast grep alternative |
| grep | 3.11 | GNU grep |
| findutils | 4.10.0 | GNU find |
| gawk | 5.3.1 | GNU awk |
| gnused | 4.9 | GNU sed |

## Compliance

### SBOM (CycloneDX)

SBOMs are generated on release and attached to GitHub releases.

```bash
# Generate SBOM locally
nix run github:nikstur/bombon -- ./.#go --output sbom.json --format cyclonedx
```

### SLSA Provenance

All releases include SLSA Level 3 provenance attestations.

```bash
# Verify provenance
slsa-verifier verify-artifact \
  --provenance-path slsa-attestation.json \
  --source-uri github.com/wellmaintained/nixpkgs \
  --source-tag v1.0.0 \
  wellmaintained-nixpkgs-v1.0.0.tar.gz
```

### CVE Triage

Security advisories are automatically processed and tracked with SLAs:
- Critical: 24h response
- High: 7d response
- Medium: 30d response

## Development

### Building Packages

```bash
# Build all packages
nix build .#default

# Build specific package
nix build .#go

# Build with verbose output
nix build .#go -vvv
```

### Running Tests

```bash
# Run flake check
nix flake check

# Run all package tests
nix build .#checks.x86_64-linux.all
```

### Devcontainer

Open in VS Code with devcontainer support:

```bash
# Requires VS Code with Dev Containers extension
# Open folder and click "Reopen in Container"
```

## CI/CD

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `sbom.yml` | Release published | Generate CycloneDX SBOM |
| `provenance.yml` | Release published | Generate SLSA provenance |
| `cache.yml` | Release published | Push to Cachix |
| `cve-triage.yml` | Security advisory | Process CVEs |

## Contributing

### Adding Packages

1. Create `pkgs/<name>/default.nix`
2. Add to overlay in `flake.nix`
3. Add metadata (description, license, homepage)
4. Test build: `nix build .#<name>`
5. Submit PR with rationale

### Updating Packages

1. Update version in `pkgs/<name>/default.nix`
2. Update `flake.lock`: `nix flake lock --update-input nixpkgs`
3. Test build: `nix build .#<name>`
4. Verify SBOM: `nix run github:nikstur/bombon -- .#<name>`

## Security

See [SECURITY.md](SECURITY.md) for CVE reporting process and SLAs.

## License

See [LICENSE](LICENSE) for details.

## Links

- [Cachix Cache](https://wellmaintained-nixpkgs.cachix.org)
- [GitHub Releases](https://github.com/wellmaintained/nixpkgs/releases)
- [SLSA Framework](https://slsa.dev)
- [CycloneDX](https://cyclonedx.org)