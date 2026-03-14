{ pkgs, sbomifySrc }:

let
  # Bake the bucket creation script, patching /usr/bin/mc to use the Nix mc path
  initScript = pkgs.runCommand "sbomify-minio-init-script" { } ''
    mkdir -p $out/opt/bin
    substitute ${sbomifySrc}/bin/create-minio-buckets.sh $out/opt/bin/create-minio-buckets.sh \
      --replace-fail "/usr/bin/mc" "${pkgs.minio-client}/bin/mc"
    chmod +x $out/opt/bin/create-minio-buckets.sh
  '';
in

pkgs.dockerTools.buildLayeredImage {
  name = "sbomify-minio-init";
  tag = "latest";

  contents = [
    pkgs.minio-client
    pkgs.bashInteractive
    pkgs.coreutils
    initScript
  ];

  config = {
    Labels = {
      "org.opencontainers.image.source" = "https://github.com/wellmaintained/packages";
      "org.opencontainers.image.description" = "sbomify MinIO Init — creates buckets for sbomify deployment";
      "org.opencontainers.image.licenses" = "Apache-2.0";
      "org.opencontainers.image.vendor" = "wellmaintained";
      "org.opencontainers.image.title" = "sbomify MinIO Init";
      "org.opencontainers.image.version" = pkgs.minio-client.version;
    };
    Entrypoint = [ "/opt/bin/create-minio-buckets.sh" ];
  };
}
