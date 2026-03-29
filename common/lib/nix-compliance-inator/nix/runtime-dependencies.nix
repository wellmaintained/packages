# runtime-dependencies.nix
#
# Produces a JSON array of store path strings in the runtime closure
# of a derivation, using nixpkgs' closureInfo.
#
# These are the store paths that actually ship at runtime — a subset
# of the full buildtime dependency graph. The Python transformer
# joins these paths with the rich metadata from
# buildtime-dependencies.nix to determine which components belong
# in the final SBOM.
{
  runCommand,
  closureInfo,
  jq,
}:

drv: extraPaths:
let
  closure = closureInfo { rootPaths = [ drv ] ++ extraPaths; };
in
runCommand "${drv.name}-runtime-dependencies.json" { } ''
  ${jq}/bin/jq -R -s '[split("\n") | .[] | select(length > 0)]' \
    < ${closure}/store-paths > $out
''
