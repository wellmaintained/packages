#!/usr/bin/env bash
set -euo pipefail

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
