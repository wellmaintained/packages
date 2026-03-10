{ pkgs }:

pkgs.dockerTools.buildLayeredImage {
  name = "redis";
  tag = "latest";

  contents = [
    pkgs.redis
  ];

  config = {
    Entrypoint = [ "${pkgs.redis}/bin/redis-server" ];
    ExposedPorts = {
      "6379/tcp" = {};
    };
    Env = [
      "REDIS_DATA=/data"
    ];
  };
}
