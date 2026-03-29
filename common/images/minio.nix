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
