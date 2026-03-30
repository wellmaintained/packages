# 0005. Collection release pipeline

Date: 2026-03-30

## Status

accepted

Supersedes the promotion section (decisions 2, 3, 6) of ADR 0003.

## Context

ADR 0003 established a build-once-promote-on-merge pipeline: images are
built on PRs with `pr-<number>-<sha7>` tags, then re-tagged on merge to
main with `latest`, `<upstream-version>`, and
`<upstream-version>-<calver>` tags. This solved the fundamental problem
of artifact integrity — the image that passes the quality gate is the
image that ships.

However, the ADR 0003 pipeline has two gaps that become visible once
real deployments and compliance workflows are involved:

**1. No concept of a release.** Merge to main triggers automatic
promotion. There is no gate between "this passed CI" and "this is
released." For a compliance-focused project, there needs to be a point
where a human says "I've verified this works" before artifacts are
considered released.

**2. No collection grouping.** Each image is promoted independently.
But sbomify — the only real consumer today — needs all 7 images to be
deployed together as a coherent set. There is no mechanism to say "these
7 image digests, at these specific versions, constitute a release." A
deployment operator has no single version string to pin against.

**3. Tag mutation.** The `latest` tag is rewritten on every merge. Tags
like `16.8` are also rewritten when the same upstream version is rebuilt.
Mutable tags undermine the immutability guarantees that make the pipeline
trustworthy.

A brainstorm session (2026-03-29) produced a design that addresses these
gaps while preserving ADR 0003's core property: build once, never
rebuild.

### Constraints

- sbomify is the only real consumer today. Individual image releases
  (e.g. releasing postgres independently) can be deferred until demand
  exists.
- GitHub mobile app breaks on tags containing `/` (slash). Tags must use
  hyphens as separators.
- The project uses a public GHCR namespace. A separate staging registry
  adds complexity without clear benefit.

## Decision

### 1. The release unit is a collection, not individual images

A release groups all images needed by a deployment (e.g. "everything
sbomify needs") under a single version string. Individual images are not
released independently — they are components of a collection.

This reflects the reality that sbomify needs postgres, redis, minio,
keycloak, the app, the frontend, and caddy to all be compatible. Releasing
them individually creates a combinatorial compatibility problem that
doesn't need to exist yet.

### 2. Three-phase pipeline: PR build → merge (pre-release) → manual promotion (release)

The pipeline has three phases with increasing trust:

| Phase | Trigger | Gate | Artifact state |
|-------|---------|------|---------------|
| PR build | Push to PR branch | Automated (CI + SBOM quality) | Candidate components |
| Pre-release | Merge to main | Branch protection (reviews, CI green) | Pre-release collection |
| Release | Human edits GitHub Release | Human judgment (deploy, verify, promote) | Released collection |

The key addition over ADR 0003 is the pre-release → release transition,
which requires human verification. This is where a deployment operator
confirms the collection works in a staging environment before it is
considered released.

### 3. Component tags at birth: `{package}-{upstream-version}-{short-sha}`

Each image receives a component tag when first built on a PR:

```
postgres-16.8-abc1234
sbomify-app-0.27.0-abc1234
redis-8.0.2-abc1234
```

This replaces the `pr-<number>-<sha7>` tagging from ADR 0003. The
component tag serves as the image's birth certificate — it encodes what
the image is (package + upstream version) and where it came from (commit
SHA), without coupling it to a PR number.

PR numbers are a GitHub concept, not an artifact concept. The component
tag is meaningful even outside GitHub's PR model.

### 4. Collection version format: `sbomify-v{app-version}-{YYYYMMDD}.{build-number}`

The collection version string identifies a specific set of image digests:

```
sbomify-v0.27.0-20260329.1
```

The components:
- `sbomify` — the collection name (the app being deployed)
- `v0.27.0` — the upstream app version being packaged
- `20260329` — the date the collection was assembled (CalVer extension)
- `.1` — build number within the same day (increments: `.1`, `.2`, etc.)

This format is used for both the git tag and the GitHub Release name.
On merge to main, every image in the collection receives this version
as an additional GHCR tag pointing to the same digest:

```
ghcr.io/wellmaintained/packages/postgres@sha256:abc123
  tags: postgres-16.8-abc1234, sbomify-v0.27.0-20260329.1
```

### 5. Immutable images, additive tags only

Images accumulate tags as they progress through gates. No tag is ever
rewritten or deleted (except PR cleanup, which removes entire PR image
versions):

```
PR build:
  @sha256:abc123                          ← digest (immutable identity)
  + postgres-16.8-abc1234                 ← component tag (birth certificate)

Merge (pre-release):
  + sbomify-v0.27.0-20260329.1            ← collection tag (membership)

Promotion (release):
  + released-on:2026-03-30T10:15:00       ← released tag (keep forever signal)
```

There is no `latest` tag. There is no mutable version tag. The SHA is the
identity; tags are metadata about what the image contains and which
collections it belongs to. Cosign signatures and attestations bind to the
digest — adding tags doesn't affect them.

### 6. Released-on tag at promotion time

The git tag `sbomify-v0.27.0-20260329.1` is created at merge time. When a
human later promotes the pre-release to a release (by unchecking
"pre-release" in the GitHub UI), the `deploy-release-website.yml` workflow
adds a `released-on:YYYY-MM-DDTHH:MM:SS` tag to every image in the
collection. This tag records the UTC timestamp of promotion and serves as
the definitive "keep forever" signal for image cleanup.

This means:
- No `-rc` suffixes in git tags
- No mutable version tags on images
- The `released-on:` tag is the only artifact mutation at promotion —
  it adds metadata without changing the image digest
- Image cleanup uses the presence of a `released-on:` tag to determine
  which images are permanently preserved

### 7. Same GHCR namespace — no staging registry

All images live in `ghcr.io/wellmaintained/packages/<name>`. There is no
separate staging or RC registry. Pre-release and released images coexist
in the same namespace, distinguished by whether their collection version
appears on a GitHub pre-release or a full release.

The repo is public, so all images are public regardless. A staging
registry would add authentication complexity, cross-registry promotion
logic, and Docker Hub-style mirroring concerns — all for no benefit in
this context.

### 8. Hyphen-separated git tags

Git tags use hyphens, not slashes:

```
sbomify-v0.27.0-20260329.1    ← correct
sbomify/v0.27.0/20260329.1    ← broken on GitHub mobile
```

GitHub's mobile app does not render slash-separated tags correctly. Since
release management happens in the GitHub UI (including mobile), tags must
work everywhere GitHub renders them.

### Resulting workflow structure

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `build.yml` | pull_request | Build all images, push with component tags, sign + attest |
| `pre-release.yml` | push to main | Create git tag, add collection tags to all images, create GitHub pre-release |
| `deploy-release-website.yml` | release: released | Add `released-on:` tags to collection images, rebuild and publish Hugo release website to GitHub Pages |
| `sbom-quality-gate.yml` | workflow_run (build, PR) | Score SBOM, compare vs baseline, block on regression |
| `sbom-quality-gate-pending.yml` | pull_request | Post placeholder comment |
| `cleanup-stale-images.yml` | schedule (weekly) | Delete images older than 7 days that lack a `released-on:` tag from GHCR |

Note: `promote.yml` from ADR 0003 is replaced by `pre-release.yml`.
The promotion step (pre-release → release) is a manual GitHub UI action,
not a workflow.

### Relation to other ADRs

Builds on ADR 0002 (`buildCompliantImage`). The build workflow calls
`nix build .#<name>` once per image, producing both the OCI image and
the CycloneDX SBOM from a single Nix evaluation. This co-derivation is
what makes build-once possible.

Supersedes ADR 0003's promotion model (decisions 2, 3, 6). ADR 0003's
core insight — build on the PR, promote the exact digest — is preserved.
What changes is how promotion works: instead of automatically re-tagging
with `latest` on merge, the pipeline creates a pre-release collection
that a human later promotes. ADR 0003's build workflow (decision 1),
cosign signing (decision 4), quality gate (decision 5), and PR image
cleanup (decision 6, with updated tag patterns) remain in effect.

Builds on ADR 0004 (repo structure). The collection concept aligns with
ADR 0004's `apps/sbomify/` structure — one app directory, one collection,
one release website.

## Consequences

### Benefits

- **Release as a first-class concept.** There is now a concrete answer
  to "what version is deployed?" — a collection version string that maps
  to a specific set of image digests.

- **Human gate before release.** The pre-release → release transition
  requires a human to verify the deployment works. This is the minimum
  viable compliance gate: someone attested that this was tested.

- **Immutable tags.** No tag is ever rewritten. A collection version
  always refers to the same set of digests. Deployment manifests that
  pin a collection version are stable forever.

- **Component traceability.** Every image tag encodes what's inside it
  (package + upstream version) and where it came from (commit SHA).
  No lookup table needed to trace an image to its source.

- **Collection coherence.** All images in a deployment are versioned
  together. No partial upgrades, no version matrix, no "which postgres
  goes with which app" questions.

- **Minimal artifact mutation at promotion.** Promoting a pre-release to
  a release adds a `released-on:` tag to each image in GHCR. The image
  digests are unchanged — only tag metadata is added. This tag serves as
  the keep-forever signal for image cleanup (7-day retention for untagged
  images).

### Trade-offs

- **Collection coupling.** All 7 images are released together even if
  only one changed. This is acceptable while sbomify is the only
  consumer, but would need revisiting if independent consumers emerge.

- **Manual promotion step.** The human gate adds latency to the release
  process. This is a feature (compliance) but also friction. If the
  team wants faster releases, the pre-release → release step could be
  automated with integration tests — but the human option should always
  remain available.

- **Build number coordination.** The `.{build-number}` suffix requires
  querying existing tags to determine the next number. This is a minor
  complexity in the pre-release workflow, but the alternative (UUID or
  timestamp) is less human-readable.

- **No individual image releases.** A consumer who only wants postgres
  cannot subscribe to postgres releases — they get the whole collection
  or nothing. Acceptable for now, revisit if demand emerges.

### Future considerations

- **Per-image release channels.** If demand for individual image
  releases emerges, the component tag scheme already supports it — a
  separate workflow could create per-image GitHub Releases.

- **Automated promotion gates.** The manual promotion step could be
  augmented with automated integration tests that run against the
  pre-release collection in a staging environment.

- **Multiple collections.** The `apps/` pattern from ADR 0004 supports
  multiple collections (e.g. `apps/sbomify/`, `apps/another-app/`),
  each with their own collection version namespace.

- **Docker-compose pinning.** The self-contained sbomify deployment
  (ADR 0004's `apps/sbomify/deployments/compose/`) could pin image
  references to specific collection versions or digests.

- **SBOM diff between releases.** The release website could show what
  changed between collection versions — new dependencies, resolved
  vulnerabilities, updated components.
