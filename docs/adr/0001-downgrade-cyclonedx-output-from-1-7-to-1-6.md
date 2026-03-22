# 0001. Downgrade CycloneDX Output from 1.7 to 1.6

Date: 2026-03-22

## Status

accepted

## Context

nix-cyclonedx-inator was generating CycloneDX 1.7 SBOMs, but sbomqs
(our SBOM quality scoring tool) v2.0.4 does not support CycloneDX 1.7.
The supported spec versions in sbomqs are hard-coded up to 1.6
(`cdxSpecVersions` in `pkg/sbom/cdx.go`). This caused the CI quality
gate to fail: sbomqs refused to score any of our generated SBOMs.

Our SBOMs do not use any features specific to the CycloneDX 1.7 spec —
the only difference is the `specVersion` field in the output JSON.

## Decision

We will downgrade nix-cyclonedx-inator's output from CycloneDX 1.7 to
1.6 so that sbomqs can score the SBOMs and the CI quality gate passes.

This is a tactical workaround, not a permanent decision. The transformer
uses cyclonedx-python-lib which supports both versions; switching back
is a one-line change (`JsonV1Dot6` → `JsonV1Dot7` in `transform.py`).

### Relation to other ADRs

None.

## Consequences

### Benefits

- sbomqs successfully scores our SBOMs (verified: score 4.08)
- CI quality gate passes without workarounds
- No loss of SBOM content — we weren't using any 1.7-specific features

### Trade-offs

- We're generating an older spec version than the library supports
- Need to remember to upgrade back when sbomqs catches up

### Future considerations

- When sbomqs adds CycloneDX 1.7 support, upgrade back to 1.7
- Monitor sbomqs releases for 1.7 compatibility
- If we start needing 1.7-specific features before sbomqs supports it,
  we'll need to evaluate alternative scoring tools
