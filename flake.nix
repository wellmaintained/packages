{
  description = "Curated nixpkgs overlay with 10 essential packages for compliance infrastructure";

  inputs = {
    # Pinned nixpkgs to specific revision (nixos-24.11 as of 2025-02-02)
    # This is a stable release with long-term support
    nixpkgs.url = "github:NixOS/nixpkgs/50ab793786d9de88ee30ec4e4c24fb4236fc2674";
  };

  outputs = { self, nixpkgs }:
    let
      # Supported systems
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # Helper to generate outputs for each system
      forEachSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = nixpkgs.legacyPackages.${system};
        inherit system;
      });

    in
    {
      # Expose the curated overlay
      overlays.default = final: prev: {
        # Import all curated packages from pkgs/ directory
        curated-go = final.callPackage ./pkgs/go { };
        curated-git = final.callPackage ./pkgs/git { };
        curated-gh = final.callPackage ./pkgs/gh { };
        curated-jq = final.callPackage ./pkgs/jq { };
        curated-ripgrep = final.callPackage ./pkgs/ripgrep { };
        curated-grep = final.callPackage ./pkgs/grep { };
        curated-findutils = final.callPackage ./pkgs/findutils { };
        curated-gawk = final.callPackage ./pkgs/gawk { };
        curated-gnused = final.callPackage ./pkgs/gnused { };
        curated-opencode = final.callPackage ./pkgs/opencode { };
      };

      # Packages output - all 10 curated packages for each system
      packages = forEachSystem ({ pkgs, system }: 
        let
          # Apply the curated overlay to get curated packages
          curatedPkgs = pkgs.extend self.overlays.default;
        in
        {
          # Individual packages
          go = curatedPkgs.curated-go;
          git = curatedPkgs.curated-git;
          gh = curatedPkgs.curated-gh;
          jq = curatedPkgs.curated-jq;
          ripgrep = curatedPkgs.curated-ripgrep;
          grep = curatedPkgs.curated-grep;
          findutils = curatedPkgs.curated-findutils;
          gawk = curatedPkgs.curated-gawk;
          gnused = curatedPkgs.curated-gnused;
          opencode = curatedPkgs.curated-opencode;
          
          # All packages combined
          default = pkgs.symlinkJoin {
            name = "curated-packages";
            paths = [
              curatedPkgs.curated-go
              curatedPkgs.curated-git
              curatedPkgs.curated-gh
              curatedPkgs.curated-jq
              curatedPkgs.curated-ripgrep
              curatedPkgs.curated-grep
              curatedPkgs.curated-findutils
              curatedPkgs.curated-gawk
              curatedPkgs.curated-gnused
              curatedPkgs.curated-opencode
            ];
            meta = with pkgs.lib; {
              description = "All 10 curated packages for compliance infrastructure";
              license = licenses.mit;
            };
          };
        }
      );

      # Development shell with all 10 packages
      devShells = forEachSystem ({ pkgs, system }:
        let
          curatedPkgs = pkgs.extend self.overlays.default;
        in
        {
          default = pkgs.mkShell {
            name = "compliance-infrastructure-shell";
            
            buildInputs = [
              curatedPkgs.curated-go
              curatedPkgs.curated-git
              curatedPkgs.curated-gh
              curatedPkgs.curated-jq
              curatedPkgs.curated-ripgrep
              curatedPkgs.curated-grep
              curatedPkgs.curated-findutils
              curatedPkgs.curated-gawk
              curatedPkgs.curated-gnused
              curatedPkgs.curated-opencode
            ];
            
            shellHook = ''
              echo "=== Compliance Infrastructure Development Shell ==="
              echo "Available curated packages (10 total):"
              echo "  1. go        - $(go version 2>/dev/null | head -1 || echo 'Go compiler')"
              echo "  2. git       - $(git --version 2>/dev/null || echo 'Git version control')"
              echo "  3. gh        - $(gh --version 2>/dev/null | head -1 || echo 'GitHub CLI')"
              echo "  4. jq        - $(jq --version 2>/dev/null || echo 'JSON processor')"
              echo "  5. ripgrep   - $(rg --version 2>/dev/null | head -1 || echo 'Fast grep alternative')"
              echo "  6. grep      - $(grep --version 2>/dev/null | head -1 || echo 'GNU grep')"
              echo "  7. findutils - $(find --version 2>/dev/null | head -1 || echo 'GNU find')"
              echo "  8. gawk      - $(awk --version 2>/dev/null | head -1 || echo 'GNU awk')"
              echo "  9. gnused    - $(sed --version 2>/dev/null | head -1 || echo 'GNU sed')"
              echo "  10. opencode - $(opencode --version 2>/dev/null || echo 'AI coding agent')"
              echo "=================================================="
            '';
            
            meta = with pkgs.lib; {
              description = "Development shell with all 10 curated packages";
            };
          };
        }
      );

      # NixOS modules (empty for now, but available for extension)
      nixosModules = {
        default = { config, lib, pkgs, ... }: {
          options = {};
          config = {};
        };
      };

      # Formatter for the flake
      formatter = forEachSystem ({ pkgs, system }: pkgs.nixpkgs-fmt);
    };
}
