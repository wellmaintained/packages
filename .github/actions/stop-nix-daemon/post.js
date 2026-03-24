const { execSync } = require("child_process");

function run(cmd) {
  try {
    console.log(`Running: ${cmd}`);
    execSync(cmd, { stdio: "inherit" });
  } catch (e) {
    console.log(`Command failed (non-fatal): ${e.message}`);
  }
}

console.log("Stopping Nix daemon to release /nix for stickydisk unmount...");

// Stop the Determinate Nix daemon (nixd)
run("sudo systemctl stop determinate-nixd.socket || true");
run("sudo systemctl stop determinate-nixd.service || true");

// Stop the classic nix-daemon if running
run("sudo systemctl stop nix-daemon.socket || true");
run("sudo systemctl stop nix-daemon.service || true");

// Kill any remaining nix processes holding /nix open
run("sudo fuser -k /nix || true");

console.log("Nix daemon stopped. /nix should be free for unmount.");
