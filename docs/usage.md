# Usage Guide

This guide explains how to consume the curated package set provided by this project.

## Consuming as a Nix Flake

You can use this project as a flake input in your own `flake.nix`. This allows you to use the curated packages or the overlay in your development environment or CI/CD pipelines.

### Adding as an Input

Add this repository to your `inputs` in `flake.nix`:

```nix
{
  inputs = {
    wellmaintained-nixpkgs.url = "github:wellmaintained/wellmaintained-nixpkgs";
    # Or use a specific tag/branch
    # wellmaintained-nixpkgs.url = "github:wellmaintained/wellmaintained-nixpkgs/v1.0.0";
  };

  outputs = { self, nixpkgs, wellmaintained-nixpkgs }: {
    # Use the curated packages
    devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
      buildInputs = [
        wellmaintained-nixpkgs.packages.x86_64-linux.go
        wellmaintained-nixpkgs.packages.x86_64-linux.opencode
      ];
    };
  };
}
```

### Using the Overlay

Alternatively, you can apply the provided overlay to your `nixpkgs` instance:

```nix
{
  outputs = { self, nixpkgs, wellmaintained-nixpkgs }: 
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ wellmaintained-nixpkgs.overlays.default ];
    };
  in {
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [
        pkgs.curated-go
        pkgs.curated-opencode
      ];
    };
  };
}
```

## Using the Devcontainer

This project provides a pre-configured VS Code Devcontainer that includes all curated tools and Nix support.

1. Open this repository in VS Code.
2. When prompted, click **Reopen in Container**.
3. Alternatively, use the Command Palette (`Ctrl+Shift+P`) and select **Dev Containers: Reopen in Container**.

The container is based on Ubuntu and includes:
- Nix package manager with Flakes enabled.
- Automatic environment loading via `nix develop`.
- VS Code extensions for Nix and direnv.

## Verifying Compliance Artifacts

Every release includes compliance artifacts that you can use to verify the integrity and security of the packages.

### Verifying SBOMs

SBOMs (Software Bill of Materials) are generated in CycloneDX format for every release.

1. Download the `cyclonedx-sbom.json` from the GitHub Release assets.
2. Use the `cyclonedx-cli` to validate the SBOM:
   ```bash
   cyclonedx validate --input-file cyclonedx-sbom.json --input-format json
   ```

### Verifying SLSA Provenance

SLSA Level 3 provenance attestations are attached to every release.

1. Install the `slsa-verifier`:
   ```bash
   go install github.com/slsa-framework/slsa-verifier/v2/cli/slsa-verifier@latest
   ```
2. Download the artifact and its attestation from the release.
3. Verify the artifact:
   ```bash
   slsa-verifier verify-artifact \
     --provenance-path slsa-attestation.intoto.jsonl \
     --source-uri github.com/wellmaintained/wellmaintained-nixpkgs \
     --source-tag v1.0.0 \
     artifact.tar.gz
   ```

## Binary Cache Usage

To speed up builds, you can use our Cachix binary cache.

### Automatic Configuration (Devcontainer)

The devcontainer is already configured to use the binary cache.

### Manual Configuration

Add the following to your `nix.conf` or `~/.config/nix/nix.conf`:

```ini
substituters = https://wellmaintained-nixpkgs.cachix.org https://cache.nixos.org
trusted-public-keys = wellmaintained-nixpkgs-1:YOUR_PUBLIC_KEY_HERE cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
```

Or use the Cachix CLI:
```bash
cachix use wellmaintained-nixpkgs
```
