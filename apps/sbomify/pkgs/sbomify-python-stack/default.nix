{ pkgs, sbomifySrc, sbomifyVenv, sbomifyFrontendStack }:

pkgs.stdenv.mkDerivation {
  pname = "sbomify-python-stack";
  version = "26.1.0";
  src = sbomifySrc;

  nativeBuildInputs = [ sbomifyVenv ];

  buildPhase = ''
    # Overlay frontend build artifacts onto source tree
    cp -r ${sbomifyFrontendStack}/sbomify/static/dist sbomify/static/dist
    cp -r ${sbomifyFrontendStack}/sbomify/static/css/* sbomify/static/css/
    cp -r ${sbomifyFrontendStack}/sbomify/static/webfonts/* sbomify/static/webfonts/

    # Run Django collectstatic with minimal settings
    cp ${./collectstatic_settings.py} collectstatic_settings.py
    export SBOMIFY_BASE_DIR=$(pwd)
    ${sbomifyVenv}/bin/python manage.py collectstatic --noinput --settings=collectstatic_settings
  '';

  installPhase = ''
    mkdir -p $out/{app,bin}

    # App source + collected static files
    cp -r sbomify manage.py pyproject.toml $out/app/
    cp -r staticfiles $out/app/staticfiles

    # Gunicorn wrapper script (all paths Nix-interpolated, GUNICORN_WORKERS is runtime)
    cat > $out/bin/sbomify-web <<'WRAPPER'
    #!/bin/sh
    exec ${sbomifyVenv}/bin/gunicorn sbomify.asgi:application \
      --bind 0.0.0.0:8000 --workers ''${GUNICORN_WORKERS:-2} \
      --worker-class uvicorn_worker.UvicornWorker \
      --graceful-timeout 30 --timeout 120 --chdir ${placeholder "out"}/app
    WRAPPER
    chmod +x $out/bin/sbomify-web

    # Expose venv for ad-hoc management commands
    ln -s ${sbomifyVenv} $out/venv
  '';

  passthru = { inherit sbomifyVenv; };
}
