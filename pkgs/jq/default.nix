{ lib, jq }:

jq.overrideAttrs (oldAttrs: {
  pname = "curated-jq";
  version = "1.7.1";
  
  meta = with lib; {
    description = "Lightweight and flexible command-line JSON processor (curated)";
    homepage = "https://jqlang.github.io/jq/";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
    longDescription = ''
      jq is a lightweight and flexible command-line JSON processor. It is
      like sed for JSON data - you can use it to slice and filter and map
      and transform structured data with the same ease that sed, awk, grep
      and friends let you play with text. This is a curated version pinned
      to 1.7.1 from nixos-24.11.
    '';
  };
})
