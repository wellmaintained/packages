# Compliance Documentation

This project is designed to provide a high level of assurance for the software it distributes. This document details the compliance features and procedures.

## SBOM Generation (CycloneDX)

We generate a Software Bill of Materials (SBOM) for every release to provide transparency into the components and dependencies of our curated packages.

- **Format**: CycloneDX JSON.
- **Tooling**: We use `bombon` (pinned to a specific commit) to generate SBOMs directly from Nix derivations.
- **Scope**: The SBOM includes all 10 curated packages and their direct dependencies.
- **Automation**: The `sbom.yml` workflow runs on every release, merges individual package SBOMs, and uploads the result as a release artifact.
- **Submission**: The SBOM is also submitted to the GitHub Dependency Submission API to enable CVE scanning.

## SLSA Level 3 Provenance

We implement SLSA (Supply-chain Levels for Software Artifacts) Level 3 to ensure the integrity of our build process.

- **Build Platform**: GitHub-hosted runners (hardened).
- **Hermeticity**: Nix builds are hermetic by design, ensuring no network access during the build process (except for fixed-output derivations).
- **Provenance Generation**: We use the official `slsa-framework/slsa-github-generator` to create signed attestations.
- **Attestation**: Every release includes a signed `.intoto.jsonl` attestation that links the built artifacts to the source code and build process.
- **Verification**: Users can verify the provenance using the `slsa-verifier` tool.

## CVE Triage Process

We proactively monitor for vulnerabilities in our curated packages.

- **Scanning**: GitHub Security scans our repository and the submitted SBOM for known CVEs.
- **Automation**: The `cve-triage.yml` workflow runs every 6 hours to identify new alerts.
- **Ticketing**: New vulnerabilities are automatically converted into GitHub Issues with appropriate severity labels and SLA targets.
- **SLA Commitments**:
  - **Critical**: 24-hour response, 7-day resolution.
  - **High**: 7-day response, 30-day resolution.
  - **Medium**: 30-day response, 90-day resolution.
- **Remediation**: Vulnerabilities are addressed by updating package versions or applying patches.

## Audit Procedures

For organizations requiring formal audits, we provide the following artifacts:

1. **Release History**: A complete history of releases with associated tags and commit hashes.
2. **Compliance Artifacts**: SBOMs and SLSA attestations for every release, stored as release assets.
3. **Security Logs**: GitHub Actions logs for all compliance workflows.
4. **CVE History**: A record of identified vulnerabilities and their remediation in the GitHub Issue tracker.

### Performing an Audit

To audit a specific release:
1. Verify the git tag and commit hash.
2. Download and validate the SBOM (`cyclonedx-sbom.json`).
3. Download and verify the SLSA provenance (`slsa-attestation.intoto.jsonl`).
4. Review the associated CVE issues in the repository.
