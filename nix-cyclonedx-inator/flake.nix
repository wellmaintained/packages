# nix-cyclonedx-inator/flake.nix
#
# Integration layer that wires together:
#   - nix/buildtime-dependencies.nix  (Nix metadata extraction)
#   - nix/runtime-dependencies.nix    (runtime store-path closure)
#   - transformer/transform.py        (JSON → CycloneDX 1.7)
#
# Exposes:
#   overlays.default  — adds buildSbom, withSbom, and withSbomAll to the package set
#   lib.withSbom      — explicit wrapper for individual derivations
#   lib.withSbomAll   — batch wrapper: withSbomAll pkgs [ "hello" "curl" ] → attrset
#   lib.buildSbom     — raw SBOM builder: buildSbom drv extraPaths → CycloneDX JSON
{
  description = "nix-cyclonedx-inator — generate CycloneDX 1.7 SBOMs from Nix derivations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # System-independent overlay that injects buildSbom and withSbom
      overlayOutput = {
        overlays.default = final: prev:
          let
            system = final.stdenv.hostPlatform.system;
          in {
            buildSbom = self.lib.${system}.buildSbom;
            withSbom = self.lib.${system}.withSbom;
            withSbomAll = self.lib.${system}.withSbomAll;
          };
      };
    in
    overlayOutput //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Python environment with cyclonedx-python-lib and packageurl-python
        transformerPython = pkgs.python3.withPackages (ps: [
          ps.cyclonedx-python-lib
          ps.packageurl-python
        ]);

        # The Nix metadata extractors
        buildtimeDeps = pkgs.callPackage ./nix/buildtime-dependencies.nix {};
        runtimeDeps = pkgs.callPackage ./nix/runtime-dependencies.nix {};
        runtimeRefGraph = pkgs.callPackage ./nix/runtime-reference-graph.nix {};

        # Core SBOM build function: derivation → CycloneDX 1.7 JSON
        buildSbom = drv: extraPaths:
          let
            buildtimeJson = buildtimeDeps drv extraPaths;
            runtimeJson = runtimeDeps drv extraPaths;
            refGraphJson = runtimeRefGraph drv extraPaths;
            drvName = drv.name or drv.pname or "unknown";
          in
          pkgs.runCommand "${drvName}-sbom-cyclonedx-1-7.json" {
            nativeBuildInputs = [ transformerPython ];
          } ''
            python3 ${./transformer/transform.py} \
              --buildtime ${buildtimeJson} \
              --runtime ${runtimeJson} \
              --references ${refGraphJson} \
              --name "${drvName}" \
              --output "$out"
          '';

        # Explicit wrapper: adds .sbom-cyclonedx-1-7 passthru to any derivation
        withSbom = drv:
          drv.overrideAttrs (old: {
            passthru = (old.passthru or {}) // {
              sbom-cyclonedx-1-7 = buildSbom drv [];
            };
          });

        # Batch wrapper: adds .sbom-cyclonedx-1-7 passthru to multiple packages
        # Usage: withSbomAll pkgs [ "hello" "curl" "jq" ]
        # Returns: { hello = <wrapped>; curl = <wrapped>; jq = <wrapped>; }
        withSbomAll = sourcePkgs: names:
          builtins.listToAttrs (map (name: {
            inherit name;
            value = withSbom sourcePkgs.${name};
          }) names);

      in
      {
        lib = {
          inherit buildSbom withSbom withSbomAll;
        };

        # Test packages for verifying end-to-end SBOM generation
        packages = {
          hello-sbom = buildSbom pkgs.hello [];
        };
      }
    );
}
