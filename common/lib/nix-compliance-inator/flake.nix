# nix-compliance-inator/flake.nix
#
# Integration layer that wires together:
#   - nix/buildtime-dependencies.nix  (Nix metadata extraction)
#   - nix/runtime-dependencies.nix    (runtime store-path closure)
#   - transformer/transform.py        (JSON → CycloneDX 1.6)
#
# Exposes:
#   overlays.default  — adds buildSbom, withSbom, withSbomAll, and buildCompliantImage to the package set
#   lib.buildCompliantImage — high-level API: image definition → { image; metadata; compliance; }
#   lib.buildSbom     — raw SBOM builder: buildSbom drv extraPaths → CycloneDX JSON
#   lib.withSbom      — explicit wrapper for individual derivations
#   lib.withSbomAll   — batch wrapper: withSbomAll pkgs [ "hello" "curl" ] → attrset
{
  description = "nix-compliance-inator — compliant OCI images with CycloneDX 1.6 SBOMs from Nix derivations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # System-independent overlay that injects buildSbom, withSbom, and buildCompliantImage
      overlayOutput = {
        overlays.default = final: prev:
          let
            system = final.stdenv.hostPlatform.system;
          in {
            buildSbom = self.lib.${system}.buildSbom;
            withSbom = self.lib.${system}.withSbom;
            withSbomAll = self.lib.${system}.withSbomAll;
            buildCompliantImage = self.lib.${system}.buildCompliantImage;
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

        # Core SBOM build function: derivation → CycloneDX 1.6 JSON
        # extraPaths: additional derivations whose dependency trees should be
        # walked for buildtime metadata (needed when packages are wrapped in
        # symlinkJoin or virtual environments that coerce deps to strings).
        buildSbom = drv: extraPaths:
          let
            buildtimeJson = buildtimeDeps drv extraPaths;
            runtimeJson = runtimeDeps drv extraPaths;
            refGraphJson = runtimeRefGraph drv extraPaths;
            drvName = drv.name or drv.pname or "unknown";
          in
          pkgs.runCommand "${drvName}-sbom-cyclonedx-1-6.json" {
            nativeBuildInputs = [ transformerPython ];
          } ''
            python3 ${./transformer/transform.py} \
              --buildtime ${buildtimeJson} \
              --runtime ${runtimeJson} \
              --references ${refGraphJson} \
              --name "${drvName}" \
              --output "$out"
          '';

        # Explicit wrapper: adds .sbom-cyclonedx-1-6 passthru to any derivation
        withSbom = drv:
          drv.overrideAttrs (old: {
            passthru = (old.passthru or {}) // {
              sbom-cyclonedx-1-6 = buildSbom drv [];
            };
          });

        # Batch wrapper: adds .sbom-cyclonedx-1-6 passthru to multiple packages
        # Usage: withSbomAll pkgs [ "hello" "curl" "jq" ]
        # Returns: { hello = <wrapped>; curl = <wrapped>; jq = <wrapped>; }
        withSbomAll = sourcePkgs: names:
          builtins.listToAttrs (map (name: {
            inherit name;
            value = withSbom sourcePkgs.${name};
          }) names);

        # Patch an SBOM's root component with OCI image metadata
        patchSbomRoot = { sbom, name, version, license, imagePrefix ? "wellmaintained/packages" }:
          let
            fullName = "${imagePrefix}/${name}-image";
            purl = "pkg:docker/${imagePrefix}/${name}@${version}";
          in
          pkgs.runCommand "${name}-sbom-patched.cdx.json" {
            nativeBuildInputs = [ pkgs.jq ];
          } ''
            jq --arg name "${fullName}" \
               --arg version "${version}" \
               --arg purl "${purl}" \
               --arg license "${license}" \
               '
              .metadata.component.name = $name |
              .metadata.component.version = $version |
              .metadata.component.type = "container" |
              .metadata.component.purl = $purl |
              .metadata.component.licenses = [{"license": {"id": $license}}] |
              .metadata.component["bom-ref"] as $root |
              .dependencies = [
                {"ref": $root, "dependsOn": [.components[]?["bom-ref"]]}
              ] + [.dependencies[]? | select(.ref != $root)]
            ' < ${sbom} > "$out"
          '';

        # High-level API: image definition → { image; metadata; compliance; }
        #
        # Returns { image; metadata; compliance; } where image carries passthru
        # attributes (.sbom, .patchedSbom, .imageMetadata) so CI can reference
        # a single package for both image and SBOM.
        buildCompliantImage = {
          name,
          version,
          license,
          description,
          tag ? "dev",
          creator ? {},
          packager ? {},
          packages,
          extraContents ? [],
          imageConfig ? {},
          extraMetadata ? {},
          fakeRootCommands ? "",
          sbomExtraDeps ? []
        }:
          let
            # Build the SBOM from a closure of all packages.
            # Pass individual packages + sbomExtraDeps as extraPaths so the
            # buildtime walker can reach their derivation attributes.
            # (symlinkJoin and mkVirtualEnv coerce deps to strings,
            # making them invisible to the walker.)
            closure = pkgs.symlinkJoin {
              name = "${name}-closure";
              paths = packages;
            };
            sbom = buildSbom closure (packages ++ sbomExtraDeps);

            # Pre-patched SBOM with OCI image root component metadata
            patchedSbom = patchSbomRoot { inherit sbom name version license; };

            # Metadata for CI consumption (nix eval --json .#<image>.imageMetadata)
            imageMetadata = {
              inherit name version license;
            } // extraMetadata;

            # OCI annotation labels derived from inputs
            labels = {
              "org.opencontainers.image.title" = name;
              "org.opencontainers.image.version" = version;
              "org.opencontainers.image.licenses" = license;
              "org.opencontainers.image.description" = description;
            } // (if packager ? name then {
              "org.opencontainers.image.vendor" = packager.name;
            } else {})
            // (if packager ? url then {
              "org.opencontainers.image.source" = packager.url;
            } else {});

            image = (pkgs.dockerTools.buildLayeredImage {
              inherit name tag fakeRootCommands;
              contents = packages ++ extraContents;
              config = imageConfig // {
                Labels = (imageConfig.Labels or {}) // labels;
              };
            }).overrideAttrs (old: {
              passthru = (old.passthru or {}) // {
                inherit sbom patchedSbom imageMetadata;
              };
            });
          in {
            inherit image;

            metadata = {
              inherit name version license creator packager;
              sbom = {
                cyclonedx-1-6 = sbom;
              };
              inherit labels;
              extra = extraMetadata;
            };

            compliance = {
              ntia-minimum-elements = {
                inherit sbom;
              };
              bsi-tr-03183-2 = {
                inherit sbom;
              };
              oci-image-spec = {
                inherit labels;
              };
            };
          };

      in
      {
        lib = {
          inherit buildSbom withSbom withSbomAll buildCompliantImage;
        };

        # Test packages for verifying end-to-end SBOM generation
        packages = {
          hello-sbom = buildSbom pkgs.hello [];
        };
      }
    );
}
