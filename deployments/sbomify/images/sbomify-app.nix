{ pkgs, sbomifyApp }:

pkgs.dockerTools.buildLayeredImage {
  name = "sbomify-app";
  tag = "latest";

  contents = [
    sbomifyApp
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.cacert
    pkgs.osv-scanner
    pkgs.cosign
  ];

  config = {
    Entrypoint = [ "${sbomifyApp}/bin/sbomify-web" ];
    ExposedPorts = {
      "8000/tcp" = {};
    };
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "PYTHONDONTWRITEBYTECODE=1"
    ];
    WorkingDir = "${sbomifyApp}/app";
  };
}
