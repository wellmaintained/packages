---
title: "sbomify"
description: "A Software Bill of Materials (SBOM) and document management platform application."
layout: hextra-home
---

<div style="margin-top: 2rem; margin-bottom: 1.5rem;">
{{< hextra/hero-headline >}}
  sbomify · v26.1.0
{{< /hextra/hero-headline >}}
</div>

<div style="margin-bottom: 1rem;">
{{< hextra/hero-subtitle >}}
  A Software Bill of Materials (SBOM) and document management platform application.
{{< /hextra/hero-subtitle >}}
</div>

<div style="text-align: center; opacity: 0.6; font-size: 0.9rem; margin-bottom: 2rem;">
  This is a <a href="https://github.com/wellmaintained/packages">wellmaintained/packages</a> distribution of the hosted <a href="https://app.sbomify.com">app.sbomify.com</a> service.
</div>

<div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 1rem; width: 100%; margin-bottom: 1rem;">

  <div style="border: 1px solid #e5e7eb; border-radius: 0.75rem; padding: 1rem 1.25rem;">
    <a href="quickstart/#deploy" style="text-decoration: none; color: inherit; font-weight: 700; white-space: nowrap;">🚀 Deploy</a>
    <br><span style="font-size: 0.8rem; opacity: 0.6;">docker-compose.yml</span>
  </div>

  <div style="border: 1px solid #e5e7eb; border-radius: 0.75rem; padding: 1rem 1.25rem;">
    <a href="quickstart/#audit-pack" style="text-decoration: none; color: inherit; font-weight: 700; white-space: nowrap;">📋 Audit Pack</a>
    <br><span style="font-size: 0.8rem; opacity: 0.6;">all compliance artifacts in one ZIP</span>
  </div>

</div>

<div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; width: 100%;">

  <div style="border: 1px solid #e5e7eb; border-radius: 0.75rem; padding: 1.25rem;">
    <div style="font-size: 1.1rem; font-weight: 700; margin-bottom: 0.5rem;"><a href="dependencies/" style="text-decoration: none; color: inherit; white-space: nowrap;">📦 Dependencies</a></div>
    <div style="font-size: 0.8rem; line-height: 1.7; opacity: 0.8;">
      7 container images<br>
      CycloneDX SBOMs
    </div>
  </div>

  <div style="border: 1px solid #e5e7eb; border-radius: 0.75rem; padding: 1.25rem;">
    <div style="font-size: 1.1rem; font-weight: 700; margin-bottom: 0.5rem;"><a href="vulnerabilities/" style="text-decoration: none; color: inherit; white-space: nowrap;">🛡️ Vulnerabilities</a></div>
    <div style="font-size: 0.8rem; line-height: 1.7; opacity: 0.8;">
      Grype CVE scans<br>
      VEX triage
    </div>
  </div>

  <div style="border: 1px solid #e5e7eb; border-radius: 0.75rem; padding: 1.25rem;">
    <div style="font-size: 1.1rem; font-weight: 700; margin-bottom: 0.5rem;"><a href="licenses/" style="text-decoration: none; color: inherit; white-space: nowrap;">⚖️ Licenses</a></div>
    <div style="font-size: 0.8rem; line-height: 1.7; opacity: 0.8;">
      License notices<br>
      Source disclosure
    </div>
  </div>

  <div style="border: 1px solid #e5e7eb; border-radius: 0.75rem; padding: 1.25rem;">
    <div style="font-size: 1.1rem; font-weight: 700; margin-bottom: 0.5rem;"><a href="provenance/" style="text-decoration: none; color: inherit; white-space: nowrap;">🔍 Provenance</a></div>
    <div style="font-size: 0.8rem; line-height: 1.7; opacity: 0.8;">
      SLSA Build Level 3<br>
      Sigstore signing
    </div>
  </div>

</div>

<div style="margin-top: 3rem; margin-bottom: 1rem;">
  <div style="font-size: 1.25rem; font-weight: 700;">Regulation Evidence Map</div>
  <div style="font-size: 0.85rem; opacity: 0.6; margin-top: 0.5rem;">
    Which release artifacts satisfy specific regulatory requirements.
  </div>
</div>

<table style="width: 100%; font-size: 0.85rem; border-collapse: collapse; margin-bottom: 2rem;">
  <thead>
    <tr>
      <th style="padding: 0.6rem 0.75rem; text-align: left; border-bottom: 2px solid #e5e7eb;">Regulation</th>
      <th style="padding: 0.6rem 0.75rem; text-align: left; border-bottom: 2px solid #e5e7eb;">Control</th>
      <th style="padding: 0.6rem 0.75rem; text-align: center; border-bottom: 2px solid #e5e7eb;"><a href="dependencies/">Dependencies</a></th>
      <th style="padding: 0.6rem 0.75rem; text-align: center; border-bottom: 2px solid #e5e7eb;"><a href="vulnerabilities/">Vulnerabilities</a></th>
      <th style="padding: 0.6rem 0.75rem; text-align: center; border-bottom: 2px solid #e5e7eb;"><a href="licenses/">Licenses</a></th>
      <th style="padding: 0.6rem 0.75rem; text-align: center; border-bottom: 2px solid #e5e7eb;"><a href="provenance/">Provenance</a></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="4" style="padding: 0.6rem 0.75rem; vertical-align: middle; font-weight: 600; border-bottom: 1px solid #e5e7eb;">Vendor<br>Security<br>Assessment</td>
      <td style="padding: 0.6rem 0.75rem;">Software composition</td>
      <td style="padding: 0.6rem 0.75rem; text-align: center;"><a href="dependencies/">✓</a></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
    </tr>
    <tr>
      <td style="padding: 0.6rem 0.75rem;">Vulnerability management</td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem; text-align: center;"><a href="vulnerabilities/">✓</a></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
    </tr>
    <tr>
      <td style="padding: 0.6rem 0.75rem;">Third-party risk</td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem; text-align: center;"><a href="licenses/">✓</a></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
    </tr>
    <tr>
      <td style="padding: 0.6rem 0.75rem; border-bottom: 1px solid #e5e7eb;">Build integrity</td>
      <td style="padding: 0.6rem 0.75rem; border-bottom: 1px solid #e5e7eb;"></td>
      <td style="padding: 0.6rem 0.75rem; border-bottom: 1px solid #e5e7eb;"></td>
      <td style="padding: 0.6rem 0.75rem; border-bottom: 1px solid #e5e7eb;"></td>
      <td style="padding: 0.6rem 0.75rem; text-align: center; border-bottom: 1px solid #e5e7eb;"><a href="provenance/">✓</a></td>
    </tr>
    <tr>
      <td rowspan="3" style="padding: 0.6rem 0.75rem; vertical-align: middle; font-weight: 600; border-bottom: 1px solid #e5e7eb;">ISO 27001</td>
      <td style="padding: 0.6rem 0.75rem;">A.8.8 Vulnerability management</td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem; text-align: center;"><a href="vulnerabilities/">✓</a></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
    </tr>
    <tr>
      <td style="padding: 0.6rem 0.75rem;">A.8.28 Secure coding</td>
      <td style="padding: 0.6rem 0.75rem; text-align: center;"><a href="dependencies/">✓</a></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem; text-align: center;"><a href="provenance/">✓</a></td>
    </tr>
    <tr>
      <td style="padding: 0.6rem 0.75rem; border-bottom: 1px solid #e5e7eb;">A.8.30 Outsourced development</td>
      <td style="padding: 0.6rem 0.75rem; text-align: center; border-bottom: 1px solid #e5e7eb;"><a href="dependencies/">✓</a></td>
      <td style="padding: 0.6rem 0.75rem; border-bottom: 1px solid #e5e7eb;"></td>
      <td style="padding: 0.6rem 0.75rem; text-align: center; border-bottom: 1px solid #e5e7eb;"><a href="licenses/">✓</a></td>
      <td style="padding: 0.6rem 0.75rem; border-bottom: 1px solid #e5e7eb;"></td>
    </tr>
    <tr>
      <td rowspan="3" style="padding: 0.6rem 0.75rem; vertical-align: middle; font-weight: 600;">CRA</td>
      <td style="padding: 0.6rem 0.75rem;">Art.13 SBOM requirement</td>
      <td style="padding: 0.6rem 0.75rem; text-align: center;"><a href="dependencies/">✓</a></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
    </tr>
    <tr>
      <td style="padding: 0.6rem 0.75rem;">Art.13(6) Vulnerability handling</td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem; text-align: center;"><a href="vulnerabilities/">✓</a></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
    </tr>
    <tr>
      <td style="padding: 0.6rem 0.75rem;">Art.13 Secure development</td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem;"></td>
      <td style="padding: 0.6rem 0.75rem; text-align: center;"><a href="provenance/">✓</a></td>
    </tr>
  </tbody>
</table>
