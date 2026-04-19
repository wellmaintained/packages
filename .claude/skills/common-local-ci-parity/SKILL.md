---
name: common-local-ci-parity
description: Use when a change adds, updates, or moves a tool used by the build pipeline, or adds CI logic that differs from local — e.g. "update hugo / grype / cosign / crane / sbomify-action / sbomqs to latest", "bump tool version", "pin tool version", "add a new tool to the pipeline", "Python-based tool", "uv tool", "uvx", "install X in CI", "pip install in CI", "npm install -g in CI", "apt-get install in the workflow", "add a GitHub Action that runs X directly", writing a workflow step that replaces a local script, editing `flake.nix` (devShells), `flake.lock`, `common/pkgs/*`, or `.github/workflows/*`.
---

# Local = CI Parity

## The Principle

A developer running the pipeline locally must execute **the same tool binaries, at the same versions, invoked by the same scripts** as CI does. "Works on my machine, fails in CI" (and the reverse) is treated as a pipeline defect, not a local-environment quirk. CI is thin — it adds authentication, artefact flow, tagging, and publishing — but never replaces build logic.

## When This Applies

- Bumping, adding, or removing a tool used anywhere in the build, scan, or packaging pipeline.
- Writing a CI workflow step that inlines a build/scan/package command.
- Adding a step to a workflow that uses `apt-get`, `pip install`, `npm install -g`, `uv pip install`, or a third-party GitHub Action that replaces a local tool.
- Creating a new script or `just` target that is called only by CI, or only by local.
- Proposing "just use setup-X action" when the equivalent tool is already provided by the Nix devShell.

## Rules

1. **Tools are pinned by the Nix flake.**
   - `flake.nix` declares the flake inputs (e.g. `nixpkgs`, `pyproject-nix`, `uv2nix`, `sbomify-action-src`) and the `devShells` (`default`, `ci`, `sbomify`) that select tool packages from those inputs.
   - `flake.lock` records the resolved input revisions. Both files are committed together; `flake.lock` is the runtime source of truth.
   - Custom-packaged tools live under `common/pkgs/<tool>/` (e.g. `common/pkgs/sbomify-action/`, `common/pkgs/sbomqs/`, `common/pkgs/sbomlyze/`).
2. **Every tool is reached through `nix develop`.**
   - Locally, `direnv` runs `nix develop` (the `default` devShell) on `cd` into the repo via `.envrc`.
   - In CI, every step that needs tools runs under `nix develop .#ci -c bash -e {0}` (see `.github/workflows/build.yml`).
   - No caller — local or CI — invokes a tool from outside the Nix-provided PATH.
3. **Core build logic lives in scripts**, not in `just` recipes or workflow YAML. `just` targets and GitHub Actions steps call the same scripts.
4. **CI adds orchestration only.**
   - Authentication (registry logins, OIDC tokens).
   - Artefact flow (uploading/downloading between jobs).
   - Tagging, promotion, publishing.
   - Nothing that changes what gets built or how.
5. **CI-only steps (push, sign, attest) are dry-runnable locally.** The local run verifies prerequisites, resolves the real commands, and prints what CI would execute — without credentials.
6. **Updating a tool is a flake operation.** Edit the input revision in `flake.nix` (or update via `nix flake update <input>`), commit the resulting `flake.lock` change. Never hand-edit a `flake.lock` revision. For tools packaged under `common/pkgs/`, bump the upstream pin in the package's Nix expression and let `nix build` recompute hashes (or rerun `prefetch`).
7. **Unified caches.** The Nix store is the single tool/dependency cache, shared across local runs and CI (via `useblacksmith/stickydisk` or the equivalent CI Nix cache). Tool databases (Grype DB, etc.) and language caches (`uv`, `bun`, Hugo) live under a project-cache root referenced by the relevant scripts so the same cache is reused across runs and worktrees.

## Common Violations

- **`pip install sbomify-action` in a workflow step.** Add the tool to the `ci` devShell (`flake.nix`) or package it under `common/pkgs/` and reference it from the devShell.
- **A GitHub Action (`setup-hugo`, `install-grype-action`, etc.) used instead of the Nix-provided tool.** CI must call the same `hugo` / `grype` / `cosign` / `crane` that the default devShell provides — via `nix develop .#ci -c <command>`. `setup-nix` is acceptable because Nix itself is the delivery mechanism — the tools Nix provides still come from the flake.
- **Pinning a tool version inside a workflow YAML.** The version lives in `flake.lock` (or in the package's Nix expression under `common/pkgs/`).
- **A `just` recipe with build logic in its body**, not delegated to a `common/lib/scripts/` script. CI cannot share that logic; parity breaks.
- **A "setup" script that exists only for CI** (or only for local). Setup is the same: clone, direnv/`.envrc`, `nix develop` resolves on first use.
- **Sign / push / attest steps that have no local dry-run path.** They cannot be rehearsed, so they only surface in CI.
- **Hand-edited revision in `flake.lock`.** The lock file is generated. Re-run `nix flake update <input>`.
- **Tool caches scattered across per-tool directories.** Unify them under the project cache root so the CI cache key is meaningful and worktrees share state.

## Decision Heuristics

- Before writing a workflow step, ask: "Can a developer reproduce this step locally by running the same command?" If no, the step is doing something only CI is allowed to do (auth, artefact flow, publishing) — or it is a violation.
- Before adding a third-party GitHub Action, ask: "Does this replace a tool the Nix devShell already provides?" If yes, don't use it.
- If the pipeline starts to diverge (`just build-local` vs `just build-ci`), back up — the divergence is the bug.
