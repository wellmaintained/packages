{ pkgs, sbomifySrc }:

pkgs.stdenv.mkDerivation {
  pname = "sbomify-frontend";
  version = "0.27.0";
  src = sbomifySrc;

  nativeBuildInputs = [ pkgs.bun pkgs.nodejs_22 pkgs.bun2nix.hook ];

  bunDeps = pkgs.bun2nix.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  # bun2nix hook runs bunNodeModulesInstallPhase (bun install from cache)
  # before buildPhase, so node_modules is ready.

  buildPhase = ''
    export HOME=$(mktemp -d)
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
