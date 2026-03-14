{ pkgs }:

pkgs.dockerTools.buildLayeredImage {
  name = "caddy";
  tag = "latest";

  contents = [
    pkgs.caddy
    pkgs.cacert
  ];

  config = {
    Labels = {
      "org.opencontainers.image.source" = "https://github.com/wellmaintained/packages";
      "org.opencontainers.image.description" = "Caddy web server — Nix-built minimal OCI image";
      "org.opencontainers.image.licenses" = "Apache-2.0";
      "org.opencontainers.image.vendor" = "wellmaintained";
      "org.opencontainers.image.title" = "Caddy";
      "org.opencontainers.image.version" = pkgs.caddy.version;
    };
    Entrypoint = [ "${pkgs.caddy}/bin/caddy" ];
    Cmd = [ "run" "--config" "/etc/caddy/Caddyfile" "--adapter" "caddyfile" ];
    ExposedPorts = {
      "80/tcp" = {};
      "443/tcp" = {};
      "443/udp" = {};
      "2019/tcp" = {};
    };
    Env = [
      "XDG_DATA_HOME=/data"
      "XDG_CONFIG_HOME=/config"
    ];
  };
}
