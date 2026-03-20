{ pkgs }:

{
  image = pkgs.dockerTools.buildLayeredImage {
    name = "minio";
    tag = "dev";

    contents = [
      pkgs.minio
      pkgs.minio-client
      pkgs.bashInteractive
      pkgs.coreutils
    ];

    config = {
      Labels = {
        "org.opencontainers.image.source" = "https://github.com/wellmaintained/packages";
        "org.opencontainers.image.description" = "MinIO object storage server — Nix-built minimal OCI image";
        "org.opencontainers.image.licenses" = pkgs.minio.meta.license.spdxId;
        "org.opencontainers.image.vendor" = "wellmaintained";
        "org.opencontainers.image.title" = "MinIO";
        "org.opencontainers.image.version" = pkgs.minio.version;
      };
      Entrypoint = [ "${pkgs.minio}/bin/minio" ];
      ExposedPorts = {
        "9000/tcp" = {};
        "9001/tcp" = {};
      };
    };
  };

  sbom = {
    closure = pkgs.symlinkJoin {
      name = "minio-closure";
      paths = [ pkgs.minio pkgs.minio-client pkgs.bashInteractive pkgs.coreutils ];
    };
    metadata = {
      name = "minio";
      version = pkgs.minio.version;
      license = pkgs.minio.meta.license.spdxId;
      sbomifyComponentId = "PLACEHOLDER_MINIO";
    };
  };
}
