{ pkgs }:

pkgs.dockerTools.buildLayeredImage {
  name = "keycloak";
  tag = "latest";

  contents = [
    pkgs.keycloak
    pkgs.cacert
  ];

  config = {
    Labels = {
      "org.opencontainers.image.source" = "https://github.com/wellmaintained/packages";
      "org.opencontainers.image.description" = "Keycloak identity provider — Nix-built minimal OCI image";
      "org.opencontainers.image.licenses" = "Apache-2.0";
      "org.opencontainers.image.vendor" = "wellmaintained";
    };
    Entrypoint = [ "${pkgs.keycloak}/bin/kc.sh" ];
    Cmd = [ "start" ];
    ExposedPorts = {
      "8080/tcp" = {};
      "8443/tcp" = {};
      "9000/tcp" = {};
    };
    Env = [
      "KC_HOME=/opt/keycloak"
    ];
  };
}
