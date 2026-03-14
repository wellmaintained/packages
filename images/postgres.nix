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
    Labels = {
      "org.opencontainers.image.source" = "https://github.com/wellmaintained/packages";
      "org.opencontainers.image.description" = "PostgreSQL 17 database — Nix-built minimal OCI image";
      "org.opencontainers.image.licenses" = "PostgreSQL";
      "org.opencontainers.image.vendor" = "wellmaintained";
      "org.opencontainers.image.title" = "PostgreSQL";
      "org.opencontainers.image.version" = pkgs.postgresql_17.version;
    };
    Entrypoint = [ "${pkgs.postgresql_17}/bin/postgres" ];
    ExposedPorts = {
      "5432/tcp" = {};
    };
    Env = [
      "PGDATA=/var/lib/postgresql/data"
    ];
  };
}
