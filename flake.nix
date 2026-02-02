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

      # Curated overlay exposing exactly 10 packages
      curatedOverlay = final: prev: {
        # Package 1: Go compiler (1.23+)
        curated-go = final.go_1_23 or final.go;
        
        # Package 2: Git version control
        curated-git = final.git;
        
        # Package 3: GitHub CLI
        curated-gh = final.gh;
        
        # Package 4: JSON processor
        curated-jq = final.jq;
        
        # Package 5: Fast grep alternative (ripgrep)
        curated-ripgrep = final.ripgrep;
        
        # Package 6: GNU grep
        curated-grep = final.gnugrep;
        
        # Package 7: GNU findutils
        curated-findutils = final.findutils;
        
        # Package 8: GNU awk
        curated-gawk = final.gawk;
        
        # Package 9: GNU sed
        curated-gnused = final.gnused;
        
        # Package 10: opencode - AI coding agent
        # Note: opencode is not in nixpkgs yet, so we create a placeholder
        # or use a similar tool. Using a placeholder derivation for now.
        curated-opencode = final.stdenv.mkDerivation {
          pname = "opencode-placeholder";
          version = "0.1.0";
          
          src = null;
          
          dontUnpack = true;
          dontBuild = true;
          
          installPhase = ''
            mkdir -p $out/bin
            cat > $out/bin/opencode << 'EOF'
          #!/bin/sh
          echo "opencode: AI coding agent placeholder"
          echo "This is a curated package in the compliance infrastructure overlay."
          echo "For the actual opencode tool, please install separately."
          EOF
            chmod +x $out/bin/opencode
          '';
          
          meta = with final.lib; {
            description = "AI coding agent (placeholder for opencode)";
            homepage = "https://github.com/opencode-ai/opencode";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.all;
          };
        };
      };

    in
    {
      # Expose the curated overlay
      overlays.default = curatedOverlay;

      # Packages output - all 10 curated packages for each system
      packages = forEachSystem ({ pkgs, system }: 
        let
          # Apply the curated overlay to get curated packages
          curatedPkgs = pkgs.extend curatedOverlay;
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
          curatedPkgs = pkgs.extend curatedOverlay;
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
              echo "  10. opencode - AI coding agent (placeholder)"
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
