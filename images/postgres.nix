{ pkgs }:

let
  postgresUid = "999";
  postgresGid = "999";

  # Passwd/group content for fakeRootCommands (written as real files, not symlinks)
  passwdContent = "root:x:0:0:root:/root:/bin/sh\npostgres:x:${postgresUid}:${postgresGid}:PostgreSQL:/var/lib/postgresql:/bin/bash";
  groupContent = "root:x:0:\npostgres:x:${postgresGid}:";
  nsswitchContent = "hosts: files dns\npasswd: files\ngroup: files";

  # Entrypoint script that handles initdb and user/database creation
  entrypoint = pkgs.writeShellScript "docker-entrypoint.sh" ''
    set -e

    PGDATA="''${PGDATA:-/var/lib/postgresql/data}"

    # Create data directory if it doesn't exist
    mkdir -p "$PGDATA"

    # Initialize database if empty
    if [ ! -s "$PGDATA/PG_VERSION" ]; then
      echo "Initializing PostgreSQL database in $PGDATA..."
      ${pkgs.postgresql_17}/bin/initdb -D "$PGDATA" --auth-local=trust --auth-host=scram-sha-256

      # Configure pg_hba.conf to allow connections
      {
        echo "local all all trust"
        echo "host all all 0.0.0.0/0 scram-sha-256"
        echo "host all all ::/0 scram-sha-256"
      } > "$PGDATA/pg_hba.conf"

      # Listen on all interfaces
      echo "listen_addresses = '*'" >> "$PGDATA/postgresql.conf"

      # Create user and database from env vars if provided
      if [ -n "''${POSTGRES_USER:-}" ] && [ "$POSTGRES_USER" != "postgres" ]; then
        ${pkgs.postgresql_17}/bin/pg_ctl -D "$PGDATA" -w start -o "-c listen_addresses="

        ${pkgs.postgresql_17}/bin/psql -v ON_ERROR_STOP=1 --username postgres \
          -c "CREATE USER \"$POSTGRES_USER\" WITH PASSWORD \$\$''${POSTGRES_PASSWORD}\$\$ CREATEDB;"

        if [ -n "''${POSTGRES_DB:-}" ]; then
          ${pkgs.postgresql_17}/bin/psql -v ON_ERROR_STOP=1 --username postgres \
            -c "CREATE DATABASE \"$POSTGRES_DB\" OWNER \"$POSTGRES_USER\";"
        fi

        ${pkgs.postgresql_17}/bin/pg_ctl -D "$PGDATA" -w stop
      elif [ -n "''${POSTGRES_PASSWORD:-}" ]; then
        ${pkgs.postgresql_17}/bin/pg_ctl -D "$PGDATA" -w start -o "-c listen_addresses="

        ${pkgs.postgresql_17}/bin/psql -v ON_ERROR_STOP=1 --username postgres \
          -c "ALTER USER postgres WITH PASSWORD \$\$''${POSTGRES_PASSWORD}\$\$;"

        if [ -n "''${POSTGRES_DB:-}" ] && [ "$POSTGRES_DB" != "postgres" ]; then
          ${pkgs.postgresql_17}/bin/psql -v ON_ERROR_STOP=1 --username postgres \
            -c "CREATE DATABASE \"$POSTGRES_DB\";"
        fi

        ${pkgs.postgresql_17}/bin/pg_ctl -D "$PGDATA" -w stop
      fi
    fi

    exec ${pkgs.postgresql_17}/bin/postgres -D "$PGDATA" "$@"
  '';
in

{
  image = pkgs.dockerTools.buildLayeredImage {
    name = "postgres";
    tag = "dev";

    contents = [
      pkgs.postgresql_17
      pkgs.cacert
      pkgs.bash
      pkgs.coreutils
    ];

    # Create directories, /etc files, and set ownership
    fakeRootCommands = ''
      mkdir -p etc
      echo -e "${passwdContent}" > etc/passwd
      echo -e "${groupContent}" > etc/group
      echo -e "${nsswitchContent}" > etc/nsswitch.conf
      mkdir -p var/lib/postgresql/data
      chown -R ${postgresUid}:${postgresGid} var/lib/postgresql
      mkdir -p run/postgresql
      chown ${postgresUid}:${postgresGid} run/postgresql
      mkdir -p root
      mkdir -p tmp
      chmod 1777 tmp
    '';

    config = {
      Labels = {
        "org.opencontainers.image.source" = "https://github.com/wellmaintained/packages";
        "org.opencontainers.image.description" = "PostgreSQL 17 database — Nix-built minimal OCI image";
        "org.opencontainers.image.licenses" = "PostgreSQL";
        "org.opencontainers.image.vendor" = "wellmaintained";
        "org.opencontainers.image.title" = "PostgreSQL";
        "org.opencontainers.image.version" = pkgs.postgresql_17.version;
      };
      Entrypoint = [ "${entrypoint}" ];
      ExposedPorts = {
        "5432/tcp" = {};
      };
      Env = [
        "PGDATA=/var/lib/postgresql/data"
      ];
      User = "${postgresUid}:${postgresGid}";
    };
  };

  sbom = {
    closure = pkgs.symlinkJoin {
      name = "postgres-closure";
      paths = [ pkgs.postgresql_17 pkgs.cacert pkgs.bash pkgs.coreutils ];
    };
    metadata = {
      name = "postgres";
      version = pkgs.postgresql_17.version;
      license = pkgs.postgresql_17.meta.license.spdxId;
      sbomifyComponentId = "M8rixM6mMEPe";
    };
  };
}
