# Security Policy

## Supported Versions

We release security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| Latest release | :white_check_mark: |
| Previous release | :white_check_mark: (critical only) |
| Older releases | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please report it responsibly.

### Reporting Process

1. **Do NOT** open a public GitHub issue for security vulnerabilities
2. Email security reports to: **security@wellmaintained.dev**
3. Include the following information:
   - Description of the vulnerability
   - Steps to reproduce (if applicable)
   - Potential impact assessment
   - Suggested fix (if known)
   - Your contact information for follow-up

### What to Expect

- **Acknowledgment**: Within 24 hours of receiving your report
- **Initial Assessment**: Within 72 hours with severity classification
- **Fix Timeline**: Based on severity (see SLA commitments below)
- **Credit**: We will publicly acknowledge your contribution (with your permission)

## SLA Commitments

We commit to the following response times for security issues:

| Severity | Response Time | Resolution Target | Description |
|----------|---------------|-------------------|-------------|
| **Critical** | 24 hours | 7 days | Remote code execution, data breach, system compromise |
| **High** | 7 days | 30 days | Significant security impact, privilege escalation |
| **Medium** | 30 days | 90 days | Moderate security impact, information disclosure |
| **Low** | 90 days | 180 days | Minor security issues, defense in depth |

### Severity Definitions

- **Critical**: Vulnerabilities that can be exploited remotely without authentication to compromise the system or data
- **High**: Vulnerabilities that allow privilege escalation or significant data exposure
- **Medium**: Vulnerabilities that require specific conditions or provide limited access
- **Low**: Minor issues, missing hardening, or theoretical vulnerabilities

## CVE Triage Workflow

Our automated CVE triage system monitors security advisories and creates tracking issues:

### How It Works

1. **Monitoring**: The system checks for new Dependabot alerts every 6 hours
2. **SBOM Analysis**: Affected packages are cross-referenced with our SBOM
3. **Issue Creation**: GitHub issues are automatically created for unpatched CVEs
4. **Auto-Assignment**: Critical and High severity issues are auto-assigned to the security team
5. **SLA Tracking**: Issues are labeled with SLA timeframes for accountability

### Issue Labels

- `CVE`: All security vulnerability issues
- `security`: Security-related issues
- `critical`/`high`/`medium`/`low`: Severity classification
- `SLA:24h`, `SLA:7d`, `SLA:30d`, `SLA:90d`: Response time commitments

### Manual Triage Process

When a CVE issue is created:

1. **Verify**: Confirm the vulnerability affects our packages
2. **Assess**: Determine exploitability in our specific context
3. **Plan**: Decide on fix approach (update, patch, or waive)
4. **Assign**: Assign to appropriate team member
5. **Track**: Update the security dashboard with status

## Security Best Practices

### For Users

- Always use the latest release
- Monitor security advisories via GitHub
- Review SBOMs attached to releases for compliance
- Verify SLSA provenance attestations

### For Contributors

- Never commit secrets or credentials
- Use the devcontainer for consistent, secure development environments
- Follow the principle of least privilege
- Report security concerns immediately

## Compliance Artifacts

Each release includes:

- **SBOM**: CycloneDX format Software Bill of Materials
- **SLSA Provenance**: Level 3 attestation for build integrity
- **CVE Scan**: Automated vulnerability scanning results

## Contact

| Purpose | Contact |
|---------|---------|
| Security Reports | security@wellmaintained.dev |
| General Questions | GitHub Discussions |
| Emergency | See repository maintainer contacts |

## Acknowledgments

We thank the following security researchers who have responsibly disclosed vulnerabilities:

*This section will be updated as vulnerabilities are reported and fixed.*

## Policy Updates

This security policy is reviewed quarterly and updated as needed. Last updated: 2026-02-02

## References

- [GitHub Security Advisories](https://github.com/wellmaintained/nixpkgs/security)
- [SLSA Framework](https://slsa.dev)
- [CycloneDX SBOM Standard](https://cyclonedx.org)
- [NIST NVD](https://nvd.nist.gov)
