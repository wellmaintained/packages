const { execSync } = require("child_process");

function run(cmd) {
  try {
    console.log(`Running: ${cmd}`);
    execSync(cmd, { stdio: "inherit" });
  } catch (e) {
    console.log(`Command failed (non-fatal): ${e.message}`);
  }
}

console.log("Stopping Nix daemon to release /nix/store for stickydisk unmount...");

// Stop the Determinate Nix daemon (nixd)
run("sudo systemctl stop determinate-nixd.socket 2>/dev/null || true");
run("sudo systemctl stop determinate-nixd.service 2>/dev/null || true");

// Stop the classic nix-daemon if running
run("sudo systemctl stop nix-daemon.socket 2>/dev/null || true");
run("sudo systemctl stop nix-daemon.service 2>/dev/null || true");

// Kill any remaining nix processes holding /nix/store open
run("sudo fuser -k /nix/store 2>/dev/null || true");

console.log("Nix daemon stopped. /nix/store should be free for unmount.");
