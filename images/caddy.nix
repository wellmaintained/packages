{ pkgs }:

pkgs.dockerTools.buildLayeredImage {
  name = "caddy";
  tag = "latest";

  contents = [
    pkgs.caddy
    pkgs.cacert
  ];

  config = {
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
