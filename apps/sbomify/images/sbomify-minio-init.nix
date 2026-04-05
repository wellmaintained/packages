{ pkgs, sbomifySrc, sbomifyVersion }:

let
  # Bake the bucket creation script, patching /usr/bin/mc to use the Nix mc path
  initScript = pkgs.runCommand "sbomify-minio-init-script" { } ''
    mkdir -p $out/opt/bin
    substitute ${sbomifySrc}/bin/create-minio-buckets.sh $out/opt/bin/create-minio-buckets.sh \
      --replace-fail "/usr/bin/mc" "${pkgs.minio-client}/bin/mc"
    chmod +x $out/opt/bin/create-minio-buckets.sh
  '';
in

pkgs.buildCompliantImage {
  name = "sbomify-minio-init";
  version = sbomifyVersion;
  license = "Apache-2.0";
  description = "sbomify MinIO Init — creates buckets for sbomify deployment";

  creator = {
    name = "sbomify";
    url = "https://sbomify.com";
  };
  packager = {
    name = "wellmaintained";
    url = "https://github.com/wellmaintained/packages";
  };

  packages = [
    pkgs.minio-client
    pkgs.busybox
  ];

  # CVE-2026-4046: iconv assertion crash via IBM1390/IBM1399 charsets (no upstream fix)
  stripFromLayers = [ "lib/gconv/IBM1390.so" "lib/gconv/IBM1399.so" ];

  extraContents = [
    initScript
  ];

  imageConfig = {
    Entrypoint = [ "/opt/bin/create-minio-buckets.sh" ];
  };

  extraMetadata = {
    sbomifyComponentId = "PLACEHOLDER_SBOMIFY_MINIO_INIT";
  };
}
