---
title: "Dependencies"
description: "Container images, deployment artifacts, and Software Bills of Materials for this release."
weight: 1
sidebar:
  open: true
---

{{< release-overview >}}

## Images

{{< release-images >}}

## SBOMs

CycloneDX SBOMs for all container images in this release. Each SBOM is
extracted from OCI attestations attached to the container image and included
here as a browsable component tree with a downloadable JSON file.

{{< sbom-summary-table >}}

### How SBOMs Are Generated

All images are built using [Nix](https://nixos.org/) derivations, producing
fully reproducible builds. SBOMs are generated during the build process and
attached to container images as [OCI attestations](https://github.com/sigstore/cosign)
in CycloneDX format.

## Previous releases

Historical releases and compliance bundles are available at
[GitHub Releases](https://github.com/wellmaintained/packages/releases).
