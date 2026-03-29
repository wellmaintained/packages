# runtime-reference-graph.nix
#
# Extracts the runtime reference graph from a derivation's closure using
# closureInfo's registration file. Each store path in the closure gets
# its list of direct runtime references.
#
# Output: JSON object mapping store paths to their references, e.g.:
#   { "/nix/store/...-foo-1.0": { "references": ["/nix/store/...-bar-2.0"] } }
{
  runCommand,
  closureInfo,
  jq,
}:

drv: extraPaths:
let
  roots = [ drv ] ++ extraPaths;
  closure = closureInfo { rootPaths = roots; };
in
runCommand "${drv.name}-runtime-reference-graph.json" {
  nativeBuildInputs = [ jq ];
} ''
  # Parse the closureInfo registration file.
  # Format per entry: storePath, narHash, narSize, emptyLine, refCount, ref1..refN
  echo '{}' > $out
  while IFS= read -r storePath; do
    read -r _narHash
    read -r _narSize
    read -r _emptyLine
    read -r refCount
    refs='[]'
    for ((i = 0; i < refCount; i++)); do
      IFS= read -r ref
      refs=$(echo "$refs" | ${jq}/bin/jq --arg r "$ref" '. + [$r]')
    done
    ${jq}/bin/jq --arg path "$storePath" --argjson refs "$refs" \
      '. + {($path): {references: $refs}}' "$out" > "$out.tmp"
    mv "$out.tmp" "$out"
  done < ${closure}/registration
''
