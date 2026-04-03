{ pkgs, sbomifyPythonStack, sbomifyFrontendStack, sbomifyVersion, sbomifyPythonDeps ? [] }:

pkgs.buildCompliantImage {
  name = "sbomify-app";
  version = sbomifyVersion;
  license = "Apache-2.0";
  description = "sbomify web application — Nix-built OCI image";

  # Individual Python package derivations from pythonSet — passed as
  # sbomExtraDeps so the SBOM buildtime walker can reach their metadata
  # (the venv bundles them as string store paths, hiding their attributes).
  sbomExtraDeps = sbomifyPythonDeps;

  creator = {
    name = "sbomify";
    url = "https://sbomify.com";
  };
  packager = {
    name = "wellmaintained";
    url = "https://github.com/wellmaintained/packages";
  };

  packages = [
    sbomifyPythonStack
    sbomifyFrontendStack
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.cacert
    pkgs.osv-scanner
    pkgs.cosign
  ];

  imageConfig = {
    Entrypoint = [ "${sbomifyPythonStack}/bin/sbomify-web" ];
    ExposedPorts = {
      "8000/tcp" = {};
    };
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "PYTHONDONTWRITEBYTECODE=1"
    ];
    WorkingDir = "${sbomifyPythonStack}/app";
  };

  extraMetadata = {
    sbomifyComponentId = "VP42I4XQgpDE";
  };
}
