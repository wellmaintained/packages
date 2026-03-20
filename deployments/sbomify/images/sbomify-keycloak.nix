{ pkgs, sbomifySrc }:

let
  # Bundle sbomify's Keycloak theme and bootstrap script into a single derivation
  sbomifyKeycloakAssets = pkgs.runCommand "sbomify-keycloak-assets" { } ''
    mkdir -p $out/opt/keycloak/themes
    cp -r ${sbomifySrc}/keycloak/themes/sbomify $out/opt/keycloak/themes/sbomify

    mkdir -p $out/opt/bin
    cp ${sbomifySrc}/bin/keycloak-bootstrap.sh $out/opt/bin/keycloak-bootstrap.sh
    chmod +x $out/opt/bin/keycloak-bootstrap.sh
  '';

  # Symlink keycloak into /opt/keycloak so kcadm.sh is at the expected path
  keycloakOptLink = pkgs.runCommand "keycloak-opt-link" { } ''
    mkdir -p $out/opt/keycloak/bin
    ln -s ${pkgs.keycloak}/bin/* $out/opt/keycloak/bin/
  '';
in

{
  image = pkgs.dockerTools.buildLayeredImage {
    name = "sbomify-keycloak";
    tag = "dev";

    contents = [
      pkgs.keycloak
      pkgs.cacert
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.findutils
      pkgs.curl
      pkgs.jq
      sbomifyKeycloakAssets
      keycloakOptLink
    ];

    config = {
      Labels = {
        "org.opencontainers.image.source" = "https://github.com/wellmaintained/packages";
        "org.opencontainers.image.description" = "sbomify Keycloak — Nix-built OCI image with sbomify theme and bootstrap script";
        "org.opencontainers.image.licenses" = pkgs.keycloak.meta.license.spdxId;
        "org.opencontainers.image.vendor" = "wellmaintained";
        "org.opencontainers.image.title" = "sbomify Keycloak";
        "org.opencontainers.image.version" = pkgs.keycloak.version;
      };
      Entrypoint = [ "${pkgs.keycloak}/bin/kc.sh" ];
      Cmd = [ "start-dev" ];
      ExposedPorts = {
        "8080/tcp" = {};
        "8443/tcp" = {};
        "9000/tcp" = {};
      };
      Env = [
        "KC_HOME=/opt/keycloak"
        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      ];
    };
  };

  sbom = {
    closure = pkgs.symlinkJoin {
      name = "sbomify-keycloak-closure";
      paths = [ pkgs.keycloak pkgs.cacert pkgs.bashInteractive pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.findutils pkgs.curl pkgs.jq ];
    };
    metadata = {
      name = "sbomify-keycloak";
      version = pkgs.keycloak.version;
      license = pkgs.keycloak.meta.license.spdxId;
      sbomifyComponentId = "N4agQD8pvej8";
    };
  };
}
