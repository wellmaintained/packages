{ pkgs, sbomifyPythonStack, sbomifyFrontendStack, sbomifyVersion, sbomifyPythonDeps ? [], sbomifyBunDeps ? [] }:

pkgs.buildCompliantImage {
  name = "sbomify-app";
  version = sbomifyVersion;
  license = "Apache-2.0";
  description = "sbomify web application — Nix-built OCI image";

  # Individual package derivations passed as sbomExtraDeps so the SBOM
  # buildtime walker can reach their metadata. Both Python (mkVirtualEnv)
  # and bun2nix (fetchBunDeps) bundle deps into single derivations,
  # hiding individual packages from the walker.
  sbomExtraDeps = sbomifyPythonDeps ++ sbomifyBunDeps;

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
    pkgs.busybox
    pkgs.cacert
    pkgs.osv-scanner
    pkgs.cosign
  ];

  # CVE-2026-4046: iconv assertion crash via IBM1390/IBM1399 charsets (no upstream fix)
  stripFromLayers = [ "lib/gconv/IBM1390.so" "lib/gconv/IBM1399.so" ];

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
