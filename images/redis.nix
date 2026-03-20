{ pkgs }:

{
  image = pkgs.dockerTools.buildLayeredImage {
    name = "redis";
    tag = "dev";

    contents = [
      pkgs.redis
    ];

    config = {
      Labels = {
        "org.opencontainers.image.source" = "https://github.com/wellmaintained/packages";
        "org.opencontainers.image.description" = "Redis server — Nix-built minimal OCI image";
        "org.opencontainers.image.licenses" = pkgs.redis.meta.license.spdxId;
        "org.opencontainers.image.vendor" = "wellmaintained";
        "org.opencontainers.image.title" = "Redis";
        "org.opencontainers.image.version" = pkgs.redis.version;
      };
      Entrypoint = [ "${pkgs.redis}/bin/redis-server" ];
      ExposedPorts = {
        "6379/tcp" = {};
      };
      Env = [
        "REDIS_DATA=/data"
      ];
    };
  };

  sbom = {
    closure = pkgs.symlinkJoin {
      name = "redis-closure";
      paths = [ pkgs.redis ];
    };
    metadata = {
      name = "redis";
      version = pkgs.redis.version;
      license = pkgs.redis.meta.license.spdxId;
      sbomifyComponentId = "ABBCcw2YiYrG";
    };
  };
}
