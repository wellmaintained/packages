{ pkgs }:

pkgs.dockerTools.buildLayeredImage {
  name = "minio-client";
  tag = "latest";

  contents = [
    pkgs.minio-client
    pkgs.bashInteractive
    pkgs.coreutils
  ];

  config = {
    Labels = {
      "org.opencontainers.image.source" = "https://github.com/wellmaintained/packages";
      "org.opencontainers.image.description" = "MinIO Client (mc) — Nix-built minimal OCI image";
      "org.opencontainers.image.licenses" = "Apache-2.0";
      "org.opencontainers.image.vendor" = "wellmaintained";
      "org.opencontainers.image.title" = "MinIO Client";
      "org.opencontainers.image.version" = pkgs.minio-client.version;
    };
  };
}
