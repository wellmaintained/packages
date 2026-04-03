{ pkgs, pyproject-nix, uv2nix, pyproject-build-systems, uv2nix-hammer-overrides, sbomify-action-src }:

let
  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = sbomify-action-src;
  };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  pythonSet =
    (pkgs.callPackage pyproject-nix.build.packages {
      python = pkgs.python313;
    }).overrideScope (
      pkgs.lib.composeManyExtensions [
        pyproject-build-systems.overlays.default
        overlay
        (uv2nix-hammer-overrides.overrides pkgs)
        # conan: sdist-only, needs CMake for native extensions
        (final: prev: {
          conan = prev.conan.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.cmake ];
          });
        })
      ]
    );

in pythonSet.mkVirtualEnv "sbomify-action-venv" workspace.deps.default
