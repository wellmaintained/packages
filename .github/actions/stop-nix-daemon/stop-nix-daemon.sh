#!/usr/bin/env bash
set -euo pipefail

# Root current derivations so they survive garbage collection.
# nix develop and nix build create ephemeral GC roots in /tmp that don't
# persist across CI runs. Without explicit rooting, GC removes everything
# the job just built, defeating the stickydisk cache.
if [ -f "${GITHUB_WORKSPACE:-.}/flake.nix" ]; then
  echo "Rooting devshells before GC..."
  cd "${GITHUB_WORKSPACE:-.}"

  gc_roots="/nix/var/nix/gcroots/stickydisk-keep"
  sudo mkdir -p "$gc_roots"
  sudo chown "$(whoami)" "$gc_roots"

  # Root CI devshell so CI tools stay cached (default devshell is for
  # local dev and its extra deps don't belong in CI stickydisks)
  nix build --out-link "$gc_roots/ci-devshell" .#devShells.x86_64-linux.ci || echo "Warning: failed to root ci devshell"

  # Root the specific image package for this matrix job (set by setup-nix)
  if [ -n "${NIX_GC_ROOT_PACKAGE:-}" ]; then
    echo "Rooting .#$NIX_GC_ROOT_PACKAGE"
    nix build --out-link "$gc_roots/$NIX_GC_ROOT_PACKAGE" ".#$NIX_GC_ROOT_PACKAGE" || echo "Warning: failed to root $NIX_GC_ROOT_PACKAGE"
  fi

fi

echo "Running nix garbage collection before stickydisk commit..."
nix-collect-garbage --delete-older-than 7d || echo "Warning: nix-collect-garbage failed (non-fatal)"

echo "Stopping Nix daemon to release /nix/store for stickydisk unmount..."

# Stop the Determinate Nix daemon (nixd)
sudo systemctl stop determinate-nixd.socket 2>/dev/null || true
sudo systemctl stop determinate-nixd.service 2>/dev/null || true

# Stop the classic nix-daemon if running
sudo systemctl stop nix-daemon.socket 2>/dev/null || true
sudo systemctl stop nix-daemon.service 2>/dev/null || true

# Kill any remaining processes holding /nix/store open
sudo fuser -k /nix/store 2>/dev/null || true

echo "Nix daemon stopped. /nix/store should be free for unmount."
