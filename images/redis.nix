{ pkgs }:

pkgs.dockerTools.buildLayeredImage {
  name = "redis";
  tag = "latest";

  contents = [
    pkgs.redis
  ];

  config = {
    Labels = {
      "org.opencontainers.image.source" = "https://github.com/wellmaintained/packages";
      "org.opencontainers.image.description" = "Redis server — Nix-built minimal OCI image";
      "org.opencontainers.image.licenses" = "AGPL-3.0-only";
      "org.opencontainers.image.vendor" = "wellmaintained";
    };
    Entrypoint = [ "${pkgs.redis}/bin/redis-server" ];
    ExposedPorts = {
      "6379/tcp" = {};
    };
    Env = [
      "REDIS_DATA=/data"
    ];
  };
}
