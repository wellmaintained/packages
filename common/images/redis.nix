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

  # CVE-2026-4046: iconv assertion crash via IBM1390/IBM1399 charsets (no upstream fix)
  stripFromLayers = [ "lib/gconv/IBM1390.so" "lib/gconv/IBM1399.so" ];

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
