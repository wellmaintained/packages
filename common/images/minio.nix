{ pkgs }:

pkgs.buildCompliantImage {
  name = "minio";
  version = pkgs.minio.version;
  license = pkgs.minio.meta.license.spdxId;
  description = "MinIO object storage server — Nix-built minimal OCI image";

  creator = {
    name = "MinIO Inc";
    url = "https://min.io";
  };
  packager = {
    name = "wellmaintained";
    url = "https://github.com/wellmaintained/packages";
  };

  packages = [
    pkgs.minio
    pkgs.minio-client
    pkgs.bashInteractive
    pkgs.coreutils
  ];

  # CVE-2026-4046: iconv assertion crash via IBM1390/IBM1399 charsets (no upstream fix)
  stripFromLayers = [ "lib/gconv/IBM1390.so" "lib/gconv/IBM1399.so" ];

  # CVE-2023-4039: Strip full gcc-lib (sanitizer/debug libs) from image;
  # replace with minimal runtime (libstdc++ + libgcc_s only).
  removeGccReferences = true;

  imageConfig = {
    Entrypoint = [ "${pkgs.minio}/bin/minio" ];
    ExposedPorts = {
      "9000/tcp" = {};
      "9001/tcp" = {};
    };
  };

  extraMetadata = {
    sbomifyComponentId = "PLACEHOLDER_MINIO";
  };
}
