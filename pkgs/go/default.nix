{ lib, go_1_23 ? null, go ? null }:

let
  goPackage = if go_1_23 != null then go_1_23 else go;
in

if goPackage == null then
  throw "Neither go_1_23 nor go available in nixpkgs"
else
  goPackage.overrideAttrs (oldAttrs: {
    pname = "curated-go";
    version = "1.23.8";
    
    meta = with lib; {
      description = "The Go programming language compiler (curated)";
      homepage = "https://go.dev/";
      license = licenses.bsd3;
      maintainers = [ ];
      platforms = platforms.all;
      longDescription = ''
        Go is an open source programming language that makes it easy to build
        simple, reliable, and efficient software. This is a curated version
        pinned to Go 1.23.8 from nixos-24.11.
      '';
    };
  })
