---
name: common-deploy-from-artifact
description: Use when a change touches the deploy / release-promotion workflow, or when proposing to build something at deploy time — e.g. "why doesn't the deploy workflow build the website?", "deploy to GitHub Pages", "rebuild the site at release", "publish the release website", "generate compliance pack at deploy", "deploy needs access to the registry", "Hugo build in deploy", "add X to the deploy step", editing `.github/workflows/deploy-release-website.yml`, `.github/workflows/pre-release.yml`, or any job that runs on the release-tag commit.
---

# Deploy is an Artefact Consumer

## The Principle

Deployable bundles (static site tarballs, compliance packs, release zips) are **built once at the pre-release moment**, where all their inputs already exist, and **attached to the GitHub release** (or equivalent artefact store). The deploy workflow downloads those pre-built bundles and publishes them. It does not build, generate, render, compile, or extract anything from registries.

## When This Applies

- A pull request adding a build step inside a deploy / release-promotion workflow.
- A proposal to "build the site at release time" because the inputs are easier to assemble then.
- A deploy workflow that requires registry credentials, tool binaries, or cache warm-up in order to run.
- Adding a new deployable (e.g. a second site, a docs bundle, a downloadable zip) and wiring up its production.
- A workflow that runs on the release-tag commit and does anything other than download + publish.

## Rules

1. **Build deployables at pre-release**, at the same time and in the same job as the compliance artefacts they depend on. Every input — SBOMs, scan reports, release notes — is already available there.
2. **Package the deployable as a single artefact** (tarball, zip, or similar) and attach it to the GitHub release (or pre-release) alongside the compliance pack.
3. **The deploy workflow's job is download + publish.** It downloads the pre-built artefact from the release and uploads it to the target (GitHub Pages, object storage, CDN). Nothing else.
4. **Deploy has no build dependencies.** It does not need the registry, Docker, a tool shim cache, or any language toolchain. The build toolchain lived at pre-release.
5. **Frozen content.** Whatever a reviewer inspects in the pre-release is exactly what gets published when the release is promoted. No regeneration, no reassembly.
6. **Deploy must be idempotent and fast.** Because it only downloads and publishes, re-running deploy is safe and takes seconds.

## Common Violations

- **`hugo build` (or any static site generator) inside the deploy workflow.** Move the build to pre-release; attach the generated tarball; deploy extracts and uploads.
- **Deploy workflow authenticates to the container registry.** If deploy needs registry access, it's generating something — which means it's a build step in disguise.
- **Deploy workflow extracts tools from images.** Tools belong at pre-release, where artefacts are assembled. Deploy has no tools.
- **Pulling compliance artefacts from the pipeline cache at deploy time.** The release contract is the attached artefact. Deploy reads from the release, not from CI cache.
- **Deploy does "one last transformation" on the artefact.** If a transformation is needed, do it at pre-release and attach the transformed result.
- **Publishing a site whose source repo state has moved on since pre-release.** The deployable is frozen at pre-release; deploy must not re-render against a moving source.
- **A deploy workflow that is long, complex, or frequently breaks.** Symptom of build steps leaking into deploy. The well-formed deploy is short and boring.

## Decision Heuristics

- Count the steps in the deploy workflow. If it's more than "download release asset → publish", you are building at deploy time.
- If the deploy workflow would work **without** Docker, language runtimes, or registry credentials, you are on the right track.
- If a reviewer says "the site on the pre-release doesn't match what actually got published", the pre-release wasn't a frozen artefact.
- If you catch yourself saying "it's easier to just rebuild here", move the build back to pre-release and attach the output. The ease comes from having an authoritative, inspectable artefact — not from saving five minutes.
- If the deploy workflow ever fails because "the registry was slow" or "the tool image couldn't be pulled", it has dependencies it should not have. Move them to pre-release.

## Two Moments to Remember

- **Pre-release is where production happens.** All artefacts (images, SBOMs, scans, deployables) exist there. Inspection, signing, and attestation happen there.
- **Release promotion is a pointer move.** It flips a flag, adds a tag, and triggers a download-and-publish. Nothing else.
