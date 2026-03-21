# runtime-dependencies.nix
#
# Produces a newline-separated list of store paths in the runtime
# closure of a derivation, using nixpkgs' closureInfo.
#
# These are the store paths that actually ship at runtime — a subset
# of the full buildtime dependency graph. The Python transformer
# joins these paths with the rich metadata from
# buildtime-dependencies.nix to determine which components belong
# in the final SBOM.
{
  runCommand,
  closureInfo,
}:

drv: extraPaths:
runCommand "${drv.name}-runtime-dependencies.txt" { } ''
  cat ${closureInfo { rootPaths = [ drv ] ++ extraPaths; }}/store-paths > $out
''
