# Maintenance Guide

This guide is for maintainers of the compliance infrastructure project. It covers adding packages, updating versions, and the release process.

## Adding New Packages (RFC Process)

The package set is strictly limited to 10 curated packages. Adding a new package requires a formal Request for Comments (RFC) process.

1. **Open an Issue**: Create a new issue with the title `RFC: Add <package-name>`.
2. **Justification**: Explain why the package is needed and how it fits into the Golang development focus.
3. **Compliance Assessment**: Verify that the package has clear licensing and can be built reproducibly.
4. **Approval**: The RFC must be approved by at least two maintainers.
5. **Implementation**:
   - Create a new directory in `pkgs/<package-name>/`.
   - Implement the derivation in `default.nix`.
   - Add the package to the `curatedOverlay` in `flake.nix`.
   - Update the documentation and package list.

## Updating Package Versions

We use pinned versions for all packages to ensure reproducibility.

### Updating Nixpkgs-based Packages

1. Find the desired version in a newer `nixpkgs` revision.
2. Update the `nixpkgs` input in `flake.nix` to the new revision hash.
3. Run `nix flake update`.
4. Update the version number in the package's `meta` attribute in `pkgs/<package>/default.nix`.
5. Verify the build: `nix build .#<package>`.

### Updating Binary Packages (e.g., opencode)

1. Find the new release on GitHub.
2. Update the `version` and `src` hashes in `pkgs/opencode/default.nix`.
3. Use `nix-prefetch-url` to get the new hashes for each platform.
4. Verify the build: `nix build .#opencode`.

## Release Process

Releases trigger the automated compliance workflows (SBOM, SLSA, Cache).

1. **Verify Builds**: Ensure all packages build locally:
   ```bash
   for pkg in go git gh jq ripgrep grep findutils gawk gnused opencode; do
     nix build ".#$pkg" --no-link
   done
   ```
2. **Run Flake Check**:
   ```bash
   nix flake check
   ```
3. **Create a Tag**:
   ```bash
   git tag -a v1.x.x -m "Release v1.x.x"
   git push origin v1.x.x
   ```
4. **Draft Release**: Create a new release on GitHub using the tag.
5. **Monitor Workflows**:
   - `SBOM Generation`: Generates and uploads CycloneDX SBOM.
   - `SLSA Provenance`: Generates and attaches SLSA Level 3 attestation.
   - `Binary Cache`: Pushes built binaries to Cachix.
6. **Verify Artifacts**: Once the workflows complete, verify that the SBOM and attestation are attached to the release.

## CVE Triage and Patching

The `cve-triage` workflow runs periodically to identify vulnerabilities in the curated packages.

1. **Review Issues**: Check for new issues created by the `cve-triage` workflow.
2. **Assess Impact**: Determine if the vulnerability affects the curated version of the package.
3. **Apply Patches**:
   - If a fix is available in a newer version, update the package.
   - If a fix is not available, consider applying a patch in the derivation.
4. **Update SLA Labels**: Ensure the issue has the correct SLA label (e.g., `SLA:24h` for Critical).
5. **Close Issue**: Once the patch is merged and a new release is made, close the issue with a reference to the fix.
