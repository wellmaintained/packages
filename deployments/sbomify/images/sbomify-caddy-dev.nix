{ pkgs, sbomifySrc }:

let
  # Use the compose-specific dev Caddyfile (HTTP-only, no TLS warnings)
  caddyConfig = pkgs.runCommand "sbomify-caddy-dev-config" { } ''
    mkdir -p $out/etc/caddy
    cp ${../compose/Caddyfile.dev} $out/etc/caddy/Caddyfile
  '';
in

{
  image = pkgs.dockerTools.buildLayeredImage {
    name = "sbomify-caddy-dev";
    tag = "dev";

    contents = [
      pkgs.caddy
      pkgs.cacert
      pkgs.wget
      caddyConfig
    ];

    config = {
      Labels = {
        "org.opencontainers.image.source" = "https://github.com/wellmaintained/packages";
        "org.opencontainers.image.description" = "sbomify Caddy (dev) — Nix-built OCI image with development Caddyfile";
        "org.opencontainers.image.licenses" = pkgs.caddy.meta.license.spdxId;
        "org.opencontainers.image.vendor" = "wellmaintained";
        "org.opencontainers.image.title" = "sbomify Caddy (dev)";
        "org.opencontainers.image.version" = pkgs.caddy.version;
      };
      Entrypoint = [ "${pkgs.caddy}/bin/caddy" ];
      Cmd = [ "run" "--config" "/etc/caddy/Caddyfile" "--adapter" "caddyfile" ];
      ExposedPorts = {
        "80/tcp" = {};
      };
      Env = [
        "XDG_DATA_HOME=/data"
        "XDG_CONFIG_HOME=/config"
      ];
    };
  };

  sbom = {
    closure = pkgs.symlinkJoin {
      name = "sbomify-caddy-dev-closure";
      paths = [ pkgs.caddy pkgs.cacert pkgs.wget ];
    };
    metadata = {
      name = "sbomify-caddy-dev";
      version = pkgs.caddy.version;
      license = pkgs.caddy.meta.license.spdxId;
      sbomifyComponentId = "zYDq6NtrOBuo";
    };
  };
}
