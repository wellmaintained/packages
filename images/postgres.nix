{ pkgs }:

pkgs.dockerTools.buildLayeredImage {
  name = "postgres";
  tag = "latest";

  contents = [
    pkgs.postgresql_17
    pkgs.cacert
    pkgs.bash
  ];

  config = {
    Entrypoint = [ "${pkgs.postgresql_17}/bin/postgres" ];
    ExposedPorts = {
      "5432/tcp" = {};
    };
    Env = [
      "PGDATA=/var/lib/postgresql/data"
    ];
  };
}
