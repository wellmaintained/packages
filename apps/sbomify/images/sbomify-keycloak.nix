{ pkgs, sbomifySrc, sbomifyKeycloakTheme }:

let
  # Bundle sbomify's Keycloak theme and bootstrap script into a single derivation
  sbomifyKeycloakAssets = pkgs.runCommand "sbomify-keycloak-assets" { } ''
    mkdir -p $out/opt/keycloak/themes
    cp -r ${sbomifyKeycloakTheme}/sbomify $out/opt/keycloak/themes/sbomify

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

pkgs.buildCompliantImage {
  name = "sbomify-keycloak";
  version = pkgs.keycloak.version;
  license = pkgs.keycloak.meta.license.spdxId;
  description = "sbomify Keycloak — Nix-built OCI image with sbomify theme and bootstrap script";

  creator = {
    name = "Red Hat";
    url = "https://www.keycloak.org";
  };
  packager = {
    name = "wellmaintained";
    url = "https://github.com/wellmaintained/packages";
  };

  packages = [
    pkgs.keycloak
    pkgs.cacert
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.findutils
    pkgs.curl
    pkgs.jq
  ];

  # CVE-2026-4046: iconv assertion crash via IBM1390/IBM1399 charsets (no upstream fix)
  stripFromLayers = [ "lib/gconv/IBM1390.so" "lib/gconv/IBM1399.so" ];

  extraContents = [
    sbomifyKeycloakAssets
    keycloakOptLink
  ];

  imageConfig = {
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

  extraMetadata = {
    sbomifyComponentId = "N4agQD8pvej8";
  };
}
