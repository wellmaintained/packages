# buildtime-dependencies.nix
#
# Walks the full dependency DAG of a derivation via genericClosure over
# drvAttrs and extracts rich metadata for each dependency. Output is a
# JSON array of objects, one per dependency.
#
# Inspired by bombon's approach but written from scratch for
# nix-compliance-inator.
{
  lib,
  writeText,
  runCommand,
  jq,
}:

let
  # Expand a derivation into all of its output derivations.
  # Each output (e.g. out, lib, dev) has a distinct outPath and is
  # treated as a separate node in the dependency graph.
  expandOutputs = drv:
    if drv ? outputs
    then map (o: drv.${o}) drv.outputs
    else [ drv ];

  # Collect the immediate dependencies of a derivation by inspecting
  # its drvAttrs. Each attribute value that is (or contains) a
  # derivation becomes an edge in the DAG.
  immediateDeps = drv:
    lib.concatLists (
      lib.mapAttrsToList (_name: value:
        if lib.isDerivation value then
          expandOutputs value
        else if lib.isList value then
          lib.concatMap expandOutputs (lib.filter lib.isDerivation value)
        else
          []
      ) drv.drvAttrs
    );

  # Wrap a derivation for use with genericClosure. The key must be
  # unique per node — outPath serves this purpose since each output
  # of each derivation has a distinct store path.
  wrapDrv = drv: {
    key = drv.outPath;
    inherit drv;
  };

  # Walk the entire buildtime dependency DAG starting from a root
  # derivation. Returns a list of { key, drv } attrsets covering
  # every reachable dependency (including the root itself).
  walkBuildtimeDeps = root:
    builtins.genericClosure {
      startSet = map wrapDrv (expandOutputs root);
      operator = item: map wrapDrv (immediateDeps item.drv);
    };

  # Safely get an attribute, returning null if missing.
  optionalAttr = name: attrs:
    if attrs ? ${name} then attrs.${name} else null;

  # Normalize a single license attrset to a consistent shape.
  normalizeLicense = l: {
    spdxId = l.spdxId or null;
    fullName = l.fullName or null;
    free = l.free or null;
  };

  # Extract license metadata as a list of normalized license objects.
  # Nix meta.license can be a single attrset or a list — always returns a list.
  extractLicenses = meta:
    if !(meta ? license) then null
    else if lib.isList meta.license
    then map normalizeLicense meta.license
    else [ (normalizeLicense meta.license) ];

  # Extract source download metadata (URLs and hash).
  extractSrc = src:
    lib.optionalAttrs (src != null && src ? urls) (
      { urls = src.urls; }
      // lib.optionalAttrs (src ? outputHash) { hash = src.outputHash; }
    );

  # Extract the meta block (license, homepage, description, etc.) from a derivation.
  extractMeta = meta:
    lib.optionalAttrs (meta != null) (
      let licenses = extractLicenses meta; in
      {}
      // lib.optionalAttrs (licenses != null) { license = licenses; }
      // lib.optionalAttrs (meta ? homepage) { homepage = meta.homepage; }
      // lib.optionalAttrs (meta ? description) { description = meta.description; }
      // lib.optionalAttrs (meta ? identifiers) { identifiers = meta.identifiers; }
      // lib.optionalAttrs (meta ? changelog) { changelog = meta.changelog; }
      // lib.optionalAttrs (meta ? mainProgram) { mainProgram = meta.mainProgram; }
      // lib.optionalAttrs (meta ? maintainers) {
        maintainers = map (m: {
          name = m.name or null;
          email = m.email or null;
          github = m.github or null;
          githubId = m.githubId or null;
        }) meta.maintainers;
      }
      // lib.optionalAttrs (meta ? knownVulnerabilities && meta.knownVulnerabilities != []) {
        knownVulnerabilities = meta.knownVulnerabilities;
      }
    );

  # Serialize patches to store paths or string paths.
  extractPatches = drv:
    map (p:
      if lib.isDerivation p then p.outPath
      else toString p
    ) (lib.flatten (drv.patches or []));

  # Detect the upstream package ecosystem from Nix builder signals.
  # Returns an ecosystem string ("pypi", "golang", etc.) or null.
  detectEcosystem = drv:
    if (drv ? meta && drv.meta ? isBuildPythonPackage) then "pypi"
    else if (drv ? goModules) then "golang"
    else if (drv ? cargoDeps) then "cargo"
    else if (drv.drvAttrs ? npmDeps) then "npm"
    else if (drv.drvAttrs ? bunDeps) then "npm"
    else null;

  # Collect the outPaths of a derivation's immediate dependencies.
  # These are the edges in the dependency DAG.
  immediateDepPaths = drv:
    lib.unique (map (dep: dep.outPath) (immediateDeps drv));

  # Extract all metadata fields we care about from a derivation.
  # Returns an attrset suitable for JSON serialization.
  extractMetadata = drv: let
    meta = optionalAttr "meta" drv;
    src = optionalAttr "src" drv;
    extractedMeta = extractMeta meta;
    extractedSrc = extractSrc src;
  in
    {
      path = drv.outPath;
      name = optionalAttr "name" drv;
      pname = optionalAttr "pname" drv;
      version = optionalAttr "version" drv;
      outputName = optionalAttr "outputName" drv;
      dependencies = immediateDepPaths drv;
    }
    // lib.optionalAttrs (extractedMeta != {}) { meta = extractedMeta; }
    // lib.optionalAttrs (extractedSrc != {}) { src = extractedSrc; }
    // { patches = extractPatches drv; }
    // { ecosystem = detectEcosystem drv; };

in

# The function interface: takes a derivation and a list of extra paths
# to include in the closure walk.
drv: extraPaths:
let
  roots = [ drv ] ++ extraPaths;

  allDeps = lib.flatten (map walkBuildtimeDeps roots);

  metadataList = map (item: extractMetadata item.drv) allDeps;

  # builtins.toJSON serializes store paths as strings but preserves their
  # string context, causing nix to warn that the writeText derivation
  # references store paths it doesn't actually need as build inputs.
  # We only record paths as metadata — discard context to silence the warning.
  rawJson = writeText "${drv.name}-buildtime-deps-raw.json" (
    builtins.unsafeDiscardStringContext (builtins.toJSON metadataList)
  );
in
# Pretty-print the JSON so downstream tools can report errors with
# meaningful line numbers.
runCommand "${drv.name}-buildtime-dependencies.json" { } ''
  ${jq}/bin/jq '.' < ${rawJson} > "$out"
''
