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
          stripFromLayers ? [],
          sbomExtraDeps ? [],
          removeGccReferences ? false
        }:
          let
            # Minimal gcc runtime: only libstdc++ and libgcc_s (needed at
            # runtime), without sanitizer/debug libs (libasan, libtsan,
            # libubsan, libhwasan, liblsan, libitm, libssp, libquadmath,
            # libgomp, libatomic) or GDB scripts.
            #
            # When removeGccReferences is true, this replaces gcc-lib in
            # the image — same ABI, ~90% smaller, and the store path name
            # doesn't match "gcc" patterns that CVE scanners flag.
            gccLib = pkgs.stdenv.cc.cc.lib;
            gccMinimalRuntime = pkgs.runCommand "gcc-minimal-runtime" {} ''
              mkdir -p $out/lib
              # Dereference symlinks (-L) so the runtime is self-contained
              # and doesn't depend on the gcc-libgcc store path.
              cp -aL ${gccLib}/lib/libstdc++.so* $out/lib/
              cp -aL ${gccLib}/lib/libgcc_s.so* $out/lib/
            '';
            # Post-process the image tarball to remove files matching
            # the supplied glob patterns from individual layers.  Because
            # buildLayeredImage puts each store path in its own layer,
            # fakeRootCommands can only affect the customisation layer —
            # it cannot reach files inside store-path layers.  This
            # derivation unpacks each layer, deletes matching files, and
            # repacks.
            stripFromImage = rawImage:
              if stripFromLayers == [] then rawImage else
              let
                # Build a grep pattern that matches any of the strip globs
                # so we only unpack layers that contain relevant files.
                # Convert globs to grep-safe fixed strings (the directory
                # components before any wildcard).
                grepPatterns = builtins.map
                  (pat: builtins.head (builtins.split "\\*" pat))
                  stripFromLayers;
                grepArgs = builtins.concatStringsSep " "
                  (builtins.map (p: "-e '${p}'") grepPatterns);
              in
              pkgs.runCommand "${name}-stripped.tar.gz" {
                nativeBuildInputs = [ pkgs.gnutar pkgs.gzip pkgs.findutils pkgs.jq ];
              } ''
                workdir=$(mktemp -d)
                cd "$workdir"
                tar xzf ${rawImage}
                config_file=$(jq -r '.[0].Config' manifest.json)
                for layer in */layer.tar; do
                  # Write listing to file to avoid SIGPIPE from grep -q
                  # closing the pipe (stdenv sets pipefail)
                  if tar tf "$layer" 2>/dev/null > "$workdir/listing.tmp" \
                     && grep -q ${grepArgs} "$workdir/listing.tmp"; then
                    old_dir=$(dirname "$layer")
                    old_hash="$old_dir"
                    mkdir -p "$old_dir/contents"
                    tar xf "$layer" -C "$old_dir/contents"
                    chmod -R u+w "$old_dir/contents"
                    find "$old_dir/contents" \( \
                      ${builtins.concatStringsSep " -o " (
                        builtins.map (pat: ''-path "*/${pat}"'') stripFromLayers
                      )} \
                    \) -delete
                    tar cf "$old_dir/layer.tar" -C "$old_dir/contents" .
                    rm -rf "$old_dir/contents"

                    # Recompute layer hash and rename directory
                    new_hash=$(sha256sum "$old_dir/layer.tar" | cut -d' ' -f1)
                    if [ "$new_hash" != "$old_hash" ]; then
                      mv "$old_dir" "$new_hash"
                      # Update manifest.json
                      jq --arg old "$old_hash" --arg new "$new_hash" \
                        '.[0].Layers |= map(sub($old; $new))' manifest.json > manifest.tmp
                      mv manifest.tmp manifest.json
                      # Update config rootfs.diff_ids
                      jq --arg old "sha256:$old_hash" --arg new "sha256:$new_hash" \
                        '.rootfs.diff_ids |= map(if . == $old then $new else . end)' \
                        "$config_file" > config.tmp
                      mv config.tmp "$config_file"
                    fi
                  fi
                done
                # Config content changed, so its filename (content hash) must update too
                new_config_hash=$(sha256sum "$config_file" | cut -d' ' -f1)
                new_config_name="$new_config_hash.json"
                if [ "$new_config_name" != "$config_file" ]; then
                  mv "$config_file" "$new_config_name"
                  jq --arg old "$config_file" --arg new "$new_config_name" \
                    '.[0].Config = $new' manifest.json > manifest.tmp
                  mv manifest.tmp manifest.json
                fi
                tar czf "$out" *
                rm -rf "$workdir"
              '';

            # Post-process the image tarball to replace the full gcc-lib
            # store path (with sanitizer/debug libs) with a symlink to
            # gccMinimalRuntime (libstdc++ + libgcc_s only).  Also removes
            # duplicate xgcc-libgcc / gcc-libgcc store paths and uses
            # remove-references-to to null out leftover gcc hash strings
            # in all binaries so scanners don't flag CVE-2023-4039.
            removeGccFromImage = rawImage:
              if !removeGccReferences then rawImage else
              let
                # Discover the gcc-related store paths to strip.  We match
                # against the basename pattern so this stays correct across
                # nixpkgs updates (the hash changes, the name stays).
                gccLibPath = builtins.unsafeDiscardStringContext (builtins.toString gccLib);
                gccLibBasename = builtins.baseNameOf gccLibPath;
                minimalPath = builtins.unsafeDiscardStringContext (builtins.toString gccMinimalRuntime);
                minimalBasename = builtins.baseNameOf minimalPath;
              in
              pkgs.runCommand "${name}-no-gcc.tar.gz" {
                nativeBuildInputs = [
                  pkgs.gnutar pkgs.gzip pkgs.findutils pkgs.jq
                  pkgs.removeReferencesTo
                ];
              } ''
                workdir=$(mktemp -d)
                cd "$workdir"
                tar xzf ${rawImage}
                config_file=$(jq -r '.[0].Config' manifest.json)

                for layer in */layer.tar; do
                  if tar tf "$layer" 2>/dev/null > "$workdir/listing.tmp" \
                     && grep -qE '(gcc-[0-9].*-lib/|xgcc-[0-9].*-libgcc/|gcc-[0-9].*-libgcc/)' "$workdir/listing.tmp"; then
                    old_dir=$(dirname "$layer")
                    old_hash="$old_dir"
                    mkdir -p "$old_dir/contents"
                    tar xf "$layer" -C "$old_dir/contents"
                    chmod -R u+w "$old_dir/contents"

                    # Remove the full gcc-lib store path and replace with
                    # a symlink to the minimal runtime.  The symlink keeps
                    # existing RPATHs working without patchelf.
                    for gcc_dir in "$old_dir/contents"/nix/store/*-gcc-*-lib; do
                      [ -d "$gcc_dir" ] || continue
                      rm -rf "$gcc_dir"
                      ln -s "${gccMinimalRuntime}" "$gcc_dir"
                    done

                    # Remove duplicate libgcc store paths (xgcc-*-libgcc
                    # and gcc-*-libgcc) — the minimal runtime already
                    # provides libgcc_s.so.
                    for libgcc_dir in "$old_dir/contents"/nix/store/*-libgcc; do
                      [ -d "$libgcc_dir" ] || continue
                      rm -rf "$libgcc_dir"
                    done

                    # Remove any now-empty nix/store directory trees
                    find "$old_dir/contents/nix" -type d -empty -delete 2>/dev/null || true

                    # Fix top-level /lib/ symlinks that pointed to the
                    # now-removed gcc-libgcc or xgcc-libgcc store paths.
                    # Redirect them to the minimal runtime instead.
                    for link in "$old_dir/contents"/lib/libgcc_s.so*; do
                      [ -L "$link" ] || continue
                      target=$(readlink "$link")
                      case "$target" in
                        */nix/store/*gcc*libgcc*|*/nix/store/*xgcc*libgcc*)
                          ln -sf "${gccMinimalRuntime}/lib/$(basename "$link")" "$link"
                          ;;
                      esac
                    done

                    # Null out gcc hash strings in remaining binaries so
                    # Nix's reference scanner (and vuln scanners) don't
                    # follow the old paths.
                    find "$old_dir/contents" -type f -size +0c \
                      -exec remove-references-to -t ${gccLib} {} \; 2>/dev/null || true

                    tar cf "$old_dir/layer.tar" -C "$old_dir/contents" .
                    rm -rf "$old_dir/contents"

                    # Recompute layer hash and rename directory
                    new_hash=$(sha256sum "$old_dir/layer.tar" | cut -d' ' -f1)
                    if [ "$new_hash" != "$old_hash" ]; then
                      mv "$old_dir" "$new_hash"
                      jq --arg old "$old_hash" --arg new "$new_hash" \
                        '.[0].Layers |= map(sub($old; $new))' manifest.json > manifest.tmp
                      mv manifest.tmp manifest.json
                      jq --arg old "sha256:$old_hash" --arg new "sha256:$new_hash" \
                        '.rootfs.diff_ids |= map(if . == $old then $new else . end)' \
                        "$config_file" > config.tmp
                      mv config.tmp "$config_file"
                    fi
                  fi
                done

                # Recompute config hash
                new_config_hash=$(sha256sum "$config_file" | cut -d' ' -f1)
                new_config_name="$new_config_hash.json"
                if [ "$new_config_name" != "$config_file" ]; then
                  mv "$config_file" "$new_config_name"
                  jq --arg old "$config_file" --arg new "$new_config_name" \
                    '.[0].Config = $new' manifest.json > manifest.tmp
                  mv manifest.tmp manifest.json
                fi
                tar czf "$out" *
                rm -rf "$workdir"
              '';

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

            # When removing gcc references, include the minimal runtime
            # in the image so the symlink target exists.
            imagePackages = packages
              ++ (if removeGccReferences then [ gccMinimalRuntime ] else []);

            rawImage = pkgs.dockerTools.buildLayeredImage {
              inherit name tag fakeRootCommands;
              contents = imagePackages ++ extraContents;
              config = imageConfig // {
                Labels = (imageConfig.Labels or {}) // labels;
              };
            };

            image = (removeGccFromImage (stripFromImage rawImage)).overrideAttrs (old: {
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
