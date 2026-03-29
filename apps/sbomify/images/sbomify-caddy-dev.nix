{ pkgs, sbomifySrc }:

let
  # Use the compose-specific dev Caddyfile (HTTP-only, no TLS warnings)
  caddyConfig = pkgs.runCommand "sbomify-caddy-dev-config" { } ''
    mkdir -p $out/etc/caddy
    cp ${../deployments/compose/Caddyfile.dev} $out/etc/caddy/Caddyfile
  '';
in

pkgs.buildCompliantImage {
  name = "sbomify-caddy-dev";
  version = pkgs.caddy.version;
  license = pkgs.caddy.meta.license.spdxId;
  description = "sbomify Caddy (dev) — Nix-built OCI image with development Caddyfile";

  creator = {
    name = "Caddy project";
    url = "https://caddyserver.com";
  };
  packager = {
    name = "wellmaintained";
    url = "https://github.com/wellmaintained/packages";
  };

  packages = [
    pkgs.caddy
    pkgs.cacert
    pkgs.wget
  ];

  extraContents = [
    caddyConfig
  ];

  imageConfig = {
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

  extraMetadata = {
    sbomifyComponentId = "zYDq6NtrOBuo";
  };
}
