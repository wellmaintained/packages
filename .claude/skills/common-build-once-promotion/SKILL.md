---
name: common-build-once-promotion
description: Use when a change would rebuild an image or regenerate compliance artefacts after the PR build — e.g. "rebuild the release image", "build during release", "build on promotion", "rebuild with the latest base", "regenerate SBOMs at release", "retag and rebuild", "tag the release image by rebuilding", or editing files matching `.github/workflows/pre-release.yml`, `.github/workflows/deploy-release-website.yml`, `.github/workflows/cleanup-stale-images.yml`, `common/lib/scripts/resolve-component-tag`, `common/lib/scripts/tag-collection`, `common/lib/scripts/cleanup-stale-images`. Also fires on proposing a workflow that runs `nix build .#<image>-image` or `docker build` after merge.
---

# Build Once, Promote via Metadata

## The Principle

An artefact is built exactly once — on the pull-request commit that produced it — and is promoted through environments by **adding metadata tags to the same digest**. A "release" is the identical bytes that passed CI, with more tags attached. Rebuilding downstream is forbidden because it replaces the tested artefact with an untested one while keeping the release labels.

## When This Applies

- A workflow, script, or `just` target that produces an image after the PR build.
- Any proposal that says "rebuild", "re-tag and rebuild", or "build the release image".
- Changes to pre-release, release-promotion, or deploy workflows that include a build step.
- Adding a new compliance artefact that would be (re)generated at promotion rather than at PR build.
- Introducing a cleanup policy that could delete a promoted artefact.

## Rules

1. **Custom images are built once, on the PR commit, and pushed with a component tag** of the form `{name}-{version}-{sha7}`. The component tag identifies the exact build.
2. **Merging to main does not rebuild.** The pre-release workflow resolves the PR's component tag to a digest and **adds** an app-collection tag (e.g. `{app}-v{version}-{YYYYMMDD}.{N}`) to that same digest.
3. **Promotion does not rebuild.** Removing the pre-release flag triggers a workflow that **adds** a `released-on:{timestamp}` tag to the same digest and publishes deployables. No `docker build`, no artefact regeneration.
4. **Compliance artefacts flow through, they do not regenerate.** SBOMs, provenance, CVE scans, and secrets scans produced at PR-build time are the artefacts that ship with the release. They are downloaded from the PR build (as CI artifacts) and assembled, not re-scanned.
5. **Stock upstream images are referenced by pinned digest** at consumption time. They do not pass through the build pipeline — only their attestations are extracted once and flow through with the rest.
6. **Cleanup respects promotion.** Only component-tagged images without a `released-on:` tag are eligible for deletion. A released digest is never cleaned up.

## Common Violations

- **A "release" workflow that runs `docker build` or calls the build script.** The release must consume, not produce. If a workflow needs the image, it downloads artefacts by component tag.
- **Regenerating SBOMs or re-running Grype in the pre-release or release workflow.** The PR build's artefacts are authoritative. Re-scanning at release time means the signed/released SBOM describes a different build than the image digest it's attached to.
- **Tagging a release by rebuilding the image with a new `--tag` argument.** Use `crane copy` / `crane mutate` or `docker buildx imagetools create` (or equivalent registry-side tag operation) to add a tag to an existing digest.
- **"Just rebuild to pick up the latest base image" after merge.** A changed base image means a new PR with a new component tag — not a silent rebuild of a released artefact.
- **Cleanup policy that treats release tags like any other tag.** The `released-on:` tag (or equivalent marker) is the signal that an image is permanent.
- **Building deployable sites or tarballs inside the deploy workflow.** Deployables are artefacts too — build them at pre-release and attach them to the GitHub release.
- **Compliance artefacts assembled at promotion time from fresh scans.** The compliance pack is assembled from the PR build's uploaded artefacts.

## Decision Heuristics

- If the pipeline adds a step after merge that produces bytes (image layers, SBOMs, site tarballs, scan reports), it is a build step in disguise. Move it earlier — to PR build or pre-release — and have the later stage consume it.
- If a question starts with "how do we rebuild X on release…", the answer is "we don't; we tag".
- If you are writing `docker build` outside the PR workflow, stop and ask whether the tag-promotion path covers the need.
- If a released image's digest differs from its PR-build digest, a rebuild happened somewhere. Find the step and remove it.
- When a new tag kind is proposed ("staging", "canary", "rollback"), treat it as another metadata-only operation on an existing digest — never as a reason to rebuild.

## Three-Phase Mental Model

| Phase | When | What produces bytes | What only adds tags |
|-------|------|---------------------|---------------------|
| PR build | Every commit on a PR | Custom images, SBOMs, scans, provenance, site inputs | — |
| Pre-release | Merge to main | Deployable bundles assembled from PR artefacts | App-collection tag on each image digest |
| Release promotion | Pre-release flag removed | — | `released-on:` tag; publish the attached deployables |

When in doubt, locate your work in that table. If it doesn't fit in a "what produces bytes" cell of an earlier phase, it probably belongs there and not where you are trying to put it.
