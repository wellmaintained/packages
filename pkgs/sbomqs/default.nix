{ pkgs }:

pkgs.buildGoModule rec {
  pname = "sbomqs";
  version = "2.0.4";

  src = pkgs.fetchFromGitHub {
    owner = "interlynk-io";
    repo = "sbomqs";
    rev = "v${version}";
    hash = "sha256-I3KxHXcAqLD94/pt2aE/V21xIN5OBVkVp5LWeIuf+iA=";
  };

  vendorHash = "sha256-yEIY5qaXiT1TNoj/t3S0CG8SR5dMr/uDEFfgdoLdSSs=";

  ldflags = [
    "-s" "-w"
    "-X sigs.k8s.io/release-utils/version.gitVersion=v${version}"
  ];

  meta = with pkgs.lib; {
    description = "SBOM quality score - assess the quality of SBOMs";
    homepage = "https://github.com/interlynk-io/sbomqs";
    license = licenses.asl20;
  };
}
