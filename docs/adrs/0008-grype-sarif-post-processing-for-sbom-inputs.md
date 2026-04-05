# 0008. Post-process grype SARIF output for SBOM inputs

Date: 2026-04-05

## Status

proposed

## Context

When grype scans an SBOM file (`sbom:<path>`) and outputs SARIF, the GitHub
Security Code Scanning UI displays poor results:

1. **Location shows "/"** — GitHub says "Preview unavailable / Sorry, we
   couldn't find this file in the repository"
2. **Message text has trailing "at: "** — a dangling suffix with nothing after it
3. **Environment is empty** — `{"image":""}` with no image name

These problems stem from grype's SARIF presenter not handling SBOM-sourced
scans. We investigated whether grype offers native controls before falling back
to post-processing.

## Investigation: grype SARIF generation

Source: [`grype/presenter/sarif/presenter.go`](https://github.com/anchore/grype/blob/main/grype/presenter/sarif/presenter.go)

### Why `artifactLocation.uri` is "/"

The `inputPath()` method (line ~157) uses a type switch on `p.src.Metadata`:
- `source.FileMetadata` → returns `m.Path`
- `source.DirectoryMetadata` → returns `m.Path`
- **Everything else** → returns `""` (empty string)

When scanning an SBOM, the metadata type is `pkg.SBOMFileMetadata`, which is
**not handled** — so `inputPath()` returns `""`. The `locations()` method
(line ~177) similarly only handles `ImageMetadata`, `FileMetadata`, and
`DirectoryMetadata`. Packages from SBOMs often have a raw location of `/`,
producing the bogus URI.

### Why `message.text` has trailing "at: "

The `resultMessage()` method (line ~230) does handle `pkg.SBOMFileMetadata`,
producing `"from SBOM file <path>"`. However, when the SBOM was originally
generated from an image scan, the SBOM's `Source.Metadata` preserves the
original `ImageMetadata` from syft. The SBOM provider only sets
`SBOMFileMetadata` when `Source.Metadata` is `nil`:

```go
// syft_sbom_provider.go
if src.Metadata == nil && path != "" {
    src.Metadata = SBOMFileMetadata{Path: path}
}
```

So the presenter falls into the `ImageMetadata` branch:
`fmt.Sprintf("in image %s at: %s", meta.UserInput, path)` — but `path` is
empty (from `packagePath()` returning `""`), producing `"at: "` with nothing
after it.

### Config options explored

- **No SARIF-specific flags exist.** `PresentationConfig` only has
  `TemplateFilePath` (template format), `ShowSuppressed` (table format), and
  `Pretty` (JSON formatting).
- **`--output template`** with a custom Go template could theoretically produce
  SARIF, but would require reimplementing all SARIF structure generation
  (rules, results, fingerprints, severity mapping) in a Go template. The
  template receives `models.Document` without access to the `go-sarif` library.
  This is impractical to write and fragile to maintain.
- **SBOM metadata flow** is partial: the SBOM file path is available in
  `SBOMFileMetadata.Path` (used in `resultMessage()`) but not in `locations()`.
  Package locations from the SBOM do flow through, but are often just `/`.

### Empty environment (`{"image":""}`)

The `properties.environment` in SARIF results comes from `p.src.Metadata` when
it is `ImageMetadata`. For SBOM inputs where the original `ImageMetadata` flows
through, the `UserInput` field may be empty or stale. This is a grype-side
limitation. We have not addressed it in this change — the SARIF `category`
field in the upload action (`vulnerability-scan/sbomify/<image>`) already
provides per-image grouping in GitHub Security.

## Decision

Post-process grype's SARIF output with `jq` in `common/lib/scripts/scan-sbom`:

1. **Replace `artifactLocation.uri`**: when `"/"` or `""`, set to the SBOM
   filename (e.g. `postgres.enriched.cdx.json`)
2. **Clean `message.text`**: strip trailing `" at: "` suffix
3. **Preserve raw output on failure**: if jq post-processing fails, warn and
   use grype's original SARIF rather than losing scan results

We chose post-processing over:
- **Upstream fix**: correct but would require a grype PR and waiting for release
- **Custom template**: impractical complexity, fragile maintenance
- **No fix**: unacceptable UX in GitHub Security

## Consequences

- GitHub Code Scanning shows the SBOM filename as the location instead of "/"
- Message text is clean without dangling "at: " suffix
- Both pre-release and weekly rescan workflows benefit (they share `scan-sbom`)
- The `jq` dependency is already available in the CI nix environment
- If grype fixes SBOM handling upstream, the post-processing becomes a no-op
  (URIs will already be non-empty, messages won't have trailing "at: ")
- Empty environment (`{"image":""}`) is not addressed; GitHub's SARIF category
  provides sufficient per-image grouping
