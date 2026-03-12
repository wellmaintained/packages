{ pkgs, sbomifySrc }:

let
  # Phase A: Fixed-output derivation for node_modules (network access allowed)
  sbomify-node-modules = pkgs.stdenv.mkDerivation {
    pname = "sbomify-node-modules";
    version = "0.27.0";
    src = sbomifySrc;

    nativeBuildInputs = [ pkgs.bun pkgs.nodejs_22 ];

    buildPhase = ''
      export HOME=$(mktemp -d)
      bun install --frozen-lockfile
    '';

    installPhase = ''
      # Tar up node_modules so the FOD output is opaque to the store-path scanner
      # (bun install creates .bin symlinks and shebangs referencing /nix/store paths)
      tar cf $out node_modules
    '';

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-tgIpvp4Z+L3WPfVDfkLF54XOWyPSU8nPtKK/eX9cwo0=";
  };
in

# Phase B: Vite build (no network, uses pre-fetched node_modules)
pkgs.stdenv.mkDerivation {
  pname = "sbomify-frontend";
  version = "0.27.0";
  src = sbomifySrc;

  nativeBuildInputs = [ pkgs.bun pkgs.nodejs_22 ];

  buildPhase = ''
    export HOME=$(mktemp -d)
    tar xf ${sbomify-node-modules}
    bun run copy-deps
    node ./node_modules/vite/bin/vite.js build
  '';

  installPhase = ''
    mkdir -p $out/sbomify/static
    cp -r sbomify/static/dist $out/sbomify/static/dist
    cp -r sbomify/static/css $out/sbomify/static/css
    cp -r sbomify/static/webfonts $out/sbomify/static/webfonts
  '';
}
