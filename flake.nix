# flake.nix
{
  description = "Wellmaintained packages - curated Nix package sets and devShells";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    bombon = {
      url = "github:nikstur/bombon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix-hammer-overrides = {
      url = "github:TyberiusPrime/uv2nix_hammer_overrides";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bun2nix = {
      url = "github:nix-community/bun2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sbomify-src = {
      url = "github:sbomify/sbomify/v0.27.0";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, bombon, pyproject-nix, uv2nix, pyproject-build-systems, uv2nix-hammer-overrides, bun2nix, sbomify-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = false;
          overlays = [ bun2nix.overlays.default ];
        };

        # Shared Python dev tools (version-agnostic); pass pythonXXXPackages as argument
        pythonDevTools = pythonPkgs: [ pythonPkgs.pip pythonPkgs.virtualenv pkgs.uv pkgs.ruff pkgs.pyright ];

        # pg_config standalone package (split from main postgresql in recent nixpkgs-unstable)
        pgConfig = pkgs.postgresql_16.pg_config;

        #############################################
        # Package Sets - composable building blocks
        #############################################
        packageSets = {

          # Foundation (always included)
          base = with pkgs; [
            bashInteractive
            coreutils
            findutils
            gnugrep
            gnused
            gawk
            gnutar
            gzip
            cacert
            tzdata
          ];

          # Developer tools
          devTools = with pkgs; [
            gitMinimal
            curl
            jq
            ripgrep
            fd
            fzf
            bat
            diffutils
            just
          ];

          # Nix tooling
          nixTools = with pkgs; [
            nix
            direnv
            nix-direnv
          ];

          # Docker / container tooling
          containerTools = with pkgs; [
            docker-client
          ];

          # Database tooling (pg_config for psycopg2, etc.)
          dbTools = [
            pgConfig
          ];

          # Language: Python 3.12
          python312 = with pkgs; [
            python312
          ];
          python312Dev = pythonDevTools pkgs.python312Packages;

          # Language: Python 3.13
          python313 = with pkgs; [
            python313
          ];
          python313Dev = pythonDevTools pkgs.python313Packages;

          # Language: Node.js
          node = with pkgs; [
            nodejs_22
          ];
          nodeDev = with pkgs; [
            nodePackages.typescript
            nodePackages.typescript-language-server
            nodePackages.prettier
            nodePackages.eslint
          ];

          # Language: Bun (fast JS runtime/bundler)
          bun = with pkgs; [
            bun
          ];

          # Language: Go
          go = with pkgs; [
            go
          ];
          goDev = with pkgs; [
            gopls
            golangci-lint
          ];

          # Language: Rust
          rust = with pkgs; [
            rustc
            cargo
          ];
          rustDev = with pkgs; [
            rust-analyzer
            clippy
            rustfmt
          ];

          # Language: Bash
          bashDev = with pkgs; [
            shellcheck
            shfmt
          ];

          # Pre-commit / code quality
          preCommit = with pkgs; [
            pre-commit
          ];
        };

        # OCI images
        postgresImage = import ./images/postgres.nix { inherit pkgs; };
        redisImage = import ./images/redis.nix { inherit pkgs; };
        minioImage = import ./images/minio.nix { inherit pkgs; };
        minioClientImage = import ./images/minio-client.nix { inherit pkgs; };

        # uv2nix: Python virtualenv from sbomify's uv.lock
        sbomifyWorkspace = uv2nix.lib.workspace.loadWorkspace {
          workspaceRoot = sbomify-src;
        };

        sbomifyOverlay = sbomifyWorkspace.mkPyprojectOverlay {
          sourcePreference = "wheel";
        };

        pythonSet =
          (pkgs.callPackage pyproject-nix.build.packages {
            python = pkgs.python313;
          }).overrideScope (
            pkgs.lib.composeManyExtensions [
              pyproject-build-systems.overlays.default
              sbomifyOverlay
              (uv2nix-hammer-overrides.overrides pkgs)
              # psycopg2: hammer_overrides hardcodes a broken pg_config path
              # (getDev postgresql has no pg_config binary in recent nixpkgs-unstable).
              # Override postPatch to use pg_config from the split package.
              (final: prev: {
                psycopg2 = prev.psycopg2.overrideAttrs (old: {
                  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.postgresql_16.pg_config ];
                  buildInputs = (old.buildInputs or []) ++ [ pkgs.postgresql_16 pkgs.openssl ];
                  postPatch = ''
                    substituteInPlace setup.py \
                      --replace-fail "self.pg_config_exe = self.build_ext.pg_config" \
                      'self.pg_config_exe = "${pkgs.postgresql_16.pg_config}/bin/pg_config"'
                  '';
                });
              })
            ]
          );

        sbomifyVenv = pythonSet.mkVirtualEnv "sbomify-venv" sbomifyWorkspace.deps.default;

        sbomifyFrontend = import ./deployments/sbomify/pkgs/sbomify-frontend {
          inherit pkgs;
          sbomifySrc = sbomify-src;
        };

        sbomifyApp = import ./deployments/sbomify/pkgs/sbomify-app {
          inherit pkgs sbomifyVenv sbomifyFrontend;
          sbomifySrc = sbomify-src;
        };

        sbomifyAppImage = import ./deployments/sbomify/images/sbomify-app.nix {
          inherit pkgs sbomifyApp;
        };

        sbomifyKeycloakImage = import ./deployments/sbomify/images/sbomify-keycloak.nix {
          inherit pkgs;
          sbomifySrc = sbomify-src;
        };

        sbomifyCaddyDevImage = import ./deployments/sbomify/images/sbomify-caddy-dev.nix {
          inherit pkgs;
          sbomifySrc = sbomify-src;
        };

        sbomifyMinioInitImage = import ./deployments/sbomify/images/sbomify-minio-init.nix {
          inherit pkgs;
          sbomifySrc = sbomify-src;
        };

      in
      {
        # Export package sets for downstream consumers
        inherit packageSets;

        # OCI images + SBOM derivations (built via bombon's buildBom)
        packages = {
          postgres-image = postgresImage;
          redis-image = redisImage;
          minio-image = minioImage;
          minio-client-image = minioClientImage;

          # CycloneDX SBOMs — build with: nix build .#<name>-sbom
          postgres-sbom = bombon.lib.${system}.buildBom postgresImage {};
          redis-sbom = bombon.lib.${system}.buildBom redisImage {};
          minio-sbom = bombon.lib.${system}.buildBom minioImage {};
          minio-client-sbom = bombon.lib.${system}.buildBom minioClientImage {};
          sbomify-app-sbom = bombon.lib.${system}.buildBom sbomifyAppImage {};

          # sbomify app packages
          sbomify-venv = sbomifyVenv;
          sbomify-frontend = sbomifyFrontend;
          sbomify-app = sbomifyApp;
          sbomify-app-image = sbomifyAppImage;
          sbomify-keycloak-image = sbomifyKeycloakImage;
          sbomify-caddy-dev-image = sbomifyCaddyDevImage;
          sbomify-minio-init-image = sbomifyMinioInitImage;
        };

        # DevShells - ready-to-use development environments
        devShells = {

          # Default: minimal shell for working on this repo
          default = pkgs.mkShell {
            name = "packages-dev";
            packages = with pkgs; [
              git
              direnv
              nix-direnv
            ];
          };

          # sbomify: Python 3.13 + Bun + Django dev environment
          sbomify = pkgs.mkShell {
            name = "sbomify-dev";
            packages =
              packageSets.devTools
              ++ packageSets.containerTools
              ++ packageSets.dbTools
              ++ packageSets.python313
              ++ packageSets.python313Dev
              ++ packageSets.bun
              ++ packageSets.node
              ++ packageSets.preCommit
              ++ packageSets.bashDev;

            shellHook = ''
              # Pin uv to the Nix-provided Python (prevents uv from downloading its own)
              export UV_PYTHON="${pkgs.python313}/bin/python3"
              export UV_PYTHON_DOWNLOADS=never

              # Expose pg_config for psycopg2 source builds
              export PG_CONFIG="${pgConfig}/bin/pg_config"

              echo ""
              echo "  wellmaintained/packages — sbomify devShell"
              echo "  Python: $(python3 --version 2>&1)"
              echo "  Bun:    $(bun --version 2>&1)"
              echo "  Node:   $(node --version 2>&1)"
              echo "  uv:     $(uv --version 2>&1)"
              echo ""
            '';
          };
        };
      }
    );
}
