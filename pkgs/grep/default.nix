{ lib, gnugrep }:

gnugrep.overrideAttrs (oldAttrs: {
  pname = "curated-grep";
  version = "3.11";
  
  meta = with lib; {
    description = "GNU grep - pattern matching and text search utility (curated)";
    homepage = "https://www.gnu.org/software/grep/";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.all;
    longDescription = ''
      Grep searches one or more input files for lines containing a match
      to a specified pattern. By default, grep prints the matching lines.
      This is the GNU implementation of grep, a curated version pinned
      to 3.11 from nixos-24.11.
    '';
  };
})
