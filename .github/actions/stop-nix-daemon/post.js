require("child_process").execSync("bash " + __dirname + "/stop-nix-daemon.sh", { stdio: "inherit" });
