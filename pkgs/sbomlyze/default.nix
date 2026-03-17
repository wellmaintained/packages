{ pkgs }:

pkgs.buildGoModule rec {
  pname = "sbomlyze";
  version = "0.3.0";

  src = pkgs.fetchFromGitHub {
    owner = "rezmoss";
    repo = "sbomlyze";
    rev = "v${version}";
    hash = "sha256-mPaJBoIRliChVEY9lieCF0LiZqouOBaWzJrGFARQNd8=";
  };

  vendorHash = "sha256-k6x2WCLKEKcl3LZPnUyUSFo8EToYq17kSRJbxUvT3pQ=";

  subPackages = [ "cmd/sbomlyze" ];

  ldflags = [
    "-s" "-w"
    "-X github.com/rezmoss/sbomlyze/internal/version.Version=${version}"
    "-X github.com/rezmoss/sbomlyze/internal/version.BuildSource=nix"
  ];

  meta = with pkgs.lib; {
    description = "SBOM analysis and diff tool";
    homepage = "https://github.com/rezmoss/sbomlyze";
    license = licenses.mit;
  };
}
