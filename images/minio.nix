{ pkgs }:

pkgs.dockerTools.buildLayeredImage {
  name = "minio";
  tag = "latest";

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
      "org.opencontainers.image.licenses" = "AGPL-3.0-or-later";
      "org.opencontainers.image.vendor" = "wellmaintained";
      "org.opencontainers.image.title" = "MinIO";
      "org.opencontainers.image.version" = pkgs.minio.version;
    };
    Entrypoint = [ "${pkgs.minio}/bin/minio" "server" "/data" "--console-address" ":9001" ];
    ExposedPorts = {
      "9000/tcp" = {};
      "9001/tcp" = {};
    };
  };
}
