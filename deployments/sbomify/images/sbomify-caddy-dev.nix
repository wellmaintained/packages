{ pkgs, sbomifySrc }:

let
  # Bake the dev Caddyfile into /etc/caddy/Caddyfile
  caddyConfig = pkgs.runCommand "sbomify-caddy-dev-config" { } ''
    mkdir -p $out/etc/caddy
    cp ${sbomifySrc}/Caddyfile.dev $out/etc/caddy/Caddyfile
  '';
in

pkgs.dockerTools.buildLayeredImage {
  name = "sbomify-caddy-dev";
  tag = "latest";

  contents = [
    pkgs.caddy
    pkgs.cacert
    caddyConfig
  ];

  config = {
    Labels = {
      "org.opencontainers.image.source" = "https://github.com/wellmaintained/packages";
      "org.opencontainers.image.description" = "sbomify Caddy (dev) — Nix-built OCI image with development Caddyfile";
      "org.opencontainers.image.licenses" = "Apache-2.0";
      "org.opencontainers.image.vendor" = "wellmaintained";
      "org.opencontainers.image.title" = "sbomify Caddy (dev)";
      "org.opencontainers.image.version" = pkgs.caddy.version;
    };
    Entrypoint = [ "${pkgs.caddy}/bin/caddy" ];
    Cmd = [ "run" "--config" "/etc/caddy/Caddyfile" "--adapter" "caddyfile" ];
    ExposedPorts = {
      "80/tcp" = {};
      "443/tcp" = {};
      "443/udp" = {};
    };
    Env = [
      "XDG_DATA_HOME=/data"
      "XDG_CONFIG_HOME=/config"
    ];
  };
}
