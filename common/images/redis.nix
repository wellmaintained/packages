{ pkgs }:

pkgs.buildCompliantImage {
  name = "redis";
  version = pkgs.redis.version;
  license = pkgs.redis.meta.license.spdxId;
  description = "Redis server — Nix-built minimal OCI image";

  creator = {
    name = "Redis Ltd";
    url = "https://redis.io";
  };
  packager = {
    name = "wellmaintained";
    url = "https://github.com/wellmaintained/packages";
  };

  packages = [ pkgs.redis ];

  imageConfig = {
    Entrypoint = [ "${pkgs.redis}/bin/redis-server" ];
    ExposedPorts = {
      "6379/tcp" = {};
    };
    Env = [
      "REDIS_DATA=/data"
    ];
  };

  extraMetadata = {
    sbomifyComponentId = "ABBCcw2YiYrG";
  };
}
