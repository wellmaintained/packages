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
      mkdir -p $out
      cp -r node_modules $out/node_modules
    '';

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = pkgs.lib.fakeHash;
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
    ln -s ${sbomify-node-modules}/node_modules ./node_modules
    bun run copy-deps
    bun x vite build
  '';

  installPhase = ''
    mkdir -p $out/sbomify/static
    cp -r sbomify/static/dist $out/sbomify/static/dist
    cp -r sbomify/static/css $out/sbomify/static/css
    cp -r sbomify/static/webfonts $out/sbomify/static/webfonts
  '';
}
