{ pkgs, sbomifyApp, sbomifyVersion }:

{
  image = pkgs.dockerTools.buildLayeredImage {
    name = "sbomify-app";
    tag = "dev";

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
  };

  sbom = {
    closure = pkgs.symlinkJoin {
      name = "sbomify-app-closure";
      paths = [ sbomifyApp pkgs.bashInteractive pkgs.coreutils pkgs.cacert pkgs.osv-scanner pkgs.cosign ];
    };
    metadata = {
      name = "sbomify-app";
      version = sbomifyVersion;
      license = "Apache-2.0";
      sbomifyComponentId = "VP42I4XQgpDE";
    };
  };
}
