# flake.nix — CI trigger (noop)
{
  description = "Wellmaintained packages - curated Nix package sets and devShells";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
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
    nix-compliance-inator = {
      url = "path:./common/lib/nix-compliance-inator";
    };
  };

  outputs = { self, nixpkgs, flake-utils, pyproject-nix, uv2nix, pyproject-build-systems, uv2nix-hammer-overrides, bun2nix, sbomify-src, nix-compliance-inator }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = false;
          overlays = [ bun2nix.overlays.default nix-compliance-inator.overlays.default ];
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

        # OCI images — each returns { image; metadata; compliance; }
        postgres = import ./common/images/postgres.nix { inherit pkgs; };
        redis = import ./common/images/redis.nix { inherit pkgs; };
        minio = import ./common/images/minio.nix { inherit pkgs; };

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

        sbomifyFrontendStack = import ./apps/sbomify/pkgs/sbomify-frontend-stack {
          inherit pkgs;
          sbomifySrc = sbomify-src;
        };

        sbomifyKeycloakTheme = import ./apps/sbomify/pkgs/sbomify-keycloak-theme {
          inherit pkgs;
          sbomifySrc = sbomify-src;
        };

        sbomifyPythonStack = import ./apps/sbomify/pkgs/sbomify-python-stack {
          inherit pkgs sbomifyVenv sbomifyFrontendStack;
          sbomifySrc = sbomify-src;
        };

        # Version derived from the pinned sbomify-src input's pyproject.toml
        sbomifyVersion = (builtins.fromTOML (builtins.readFile (sbomify-src + "/pyproject.toml"))).project.version;

        sbomifyAppSpec = import ./apps/sbomify/images/sbomify-app.nix {
          inherit pkgs sbomifyPythonStack sbomifyFrontendStack sbomifyVersion;
        };

        sbomifyKeycloakSpec = import ./apps/sbomify/images/sbomify-keycloak.nix {
          inherit pkgs sbomifyKeycloakTheme;
          sbomifySrc = sbomify-src;
        };

        sbomifyCaddyDevSpec = import ./apps/sbomify/images/sbomify-caddy-dev.nix {
          inherit pkgs;
          sbomifySrc = sbomify-src;
        };

        sbomifyMinioInitSpec = import ./apps/sbomify/images/sbomify-minio-init.nix {
          inherit pkgs sbomifyVersion;
          sbomifySrc = sbomify-src;
        };

        # SBOM quality tools
        sbomqs = import ./common/pkgs/sbomqs { inherit pkgs; };
        sbomlyze = import ./common/pkgs/sbomlyze { inherit pkgs; };

      in
      {
        # Export package sets for downstream consumers
        inherit packageSets;

        # OCI images — each carries passthru: .sbom, .patchedSbom, .imageMetadata
        # CI uses a single package ref per image:
        #   nix build .#postgres-image            → OCI image tarball
        #   nix build .#postgres-image.patchedSbom → patched CycloneDX 1.6 SBOM
        #   nix eval --json .#postgres-image.imageMetadata → { name, version, ... }
        packages = {
          # Images (unified: image + SBOM + metadata from one package)
          postgres-image = postgres.image;
          redis-image = redis.image;
          minio-image = minio.image;
          sbomify-app-image = sbomifyAppSpec.image;
          sbomify-keycloak-image = sbomifyKeycloakSpec.image;
          sbomify-caddy-dev-image = sbomifyCaddyDevSpec.image;
          sbomify-minio-init-image = sbomifyMinioInitSpec.image;

          # SBOM quality tools
          inherit sbomqs sbomlyze;

          # sbomify app packages
          sbomify-venv = sbomifyVenv;
          sbomify-frontend-stack = sbomifyFrontendStack;
          sbomify-python-stack = sbomifyPythonStack;
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
              cyclonedx-cli
              cosign
              crane
            ];
          };

          # CI: tools needed by GitHub Actions workflows
          ci = pkgs.mkShell {
            packages = with pkgs; [
              cosign
              crane
              grype
              sbomqs
              sbomlyze
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
