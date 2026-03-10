{ pkgs }:

pkgs.dockerTools.buildLayeredImage {
  name = "keycloak";
  tag = "latest";

  contents = [
    pkgs.keycloak
    pkgs.cacert
  ];

  config = {
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
