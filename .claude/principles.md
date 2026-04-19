# Pipeline Design Principles

When work touches the build, compliance, or deploy pipeline, these
principles apply. If the current task relates to one of them, invoke
the named skill for the full rules.

- **Build once, promote via metadata.** Artefacts are built on PR,
  promoted by adding tags. Never rebuilt downstream.
  → `common-build-once-promotion`

- **One command, all compliance outputs.** Image + SBOMs + scans +
  provenance in a single invocation. No partial states.
  → `common-unified-compliance-output`

- **Deploy is an artefact consumer, not a builder.** Build deployables
  at pre-release; deploy downloads and publishes.
  → `common-deploy-from-artifact`

- **Local = CI.** Same tools, versions, scripts. Nix devShells provide
  identical toolchains. CI adds orchestration, never replaces build logic.
  → `common-local-ci-parity`

- **SBOMs derive from the build.** Single source of truth via Nix
  derivations; conversion preserves relationships.
  → `common-authoritative-sboms`

- **Enrich after conversion, keep the raw.** Enrichment runs on the
  converted format; the build's raw SBOM stays unchanged.
  → `common-sbom-enrichment`
