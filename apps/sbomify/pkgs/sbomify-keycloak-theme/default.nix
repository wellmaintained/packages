{ pkgs, sbomifySrc }:

pkgs.runCommand "sbomify-keycloak-theme" {
  nativeBuildInputs = [ pkgs.tailwindcss ];
} ''
  cp -r ${sbomifySrc}/keycloak/themes $TMPDIR/themes
  cp ${sbomifySrc}/keycloak/tailwind.config.ts $TMPDIR/tailwind.config.ts
  chmod -R u+w $TMPDIR/themes

  cd $TMPDIR
  tailwindcss \
    -c tailwind.config.ts \
    -i themes/sbomify/login/resources/css/sbomify.src.css \
    -o themes/sbomify/login/resources/css/sbomify.css \
    --minify

  mkdir -p $out
  cp -r $TMPDIR/themes/sbomify $out/sbomify
''
