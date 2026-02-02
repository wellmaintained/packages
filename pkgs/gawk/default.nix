{ lib, gawk }:

gawk.overrideAttrs (oldAttrs: {
  pname = "curated-gawk";
  version = "5.3.1";
  
  meta = with lib; {
    description = "GNU awk - pattern scanning and processing language (curated)";
    homepage = "https://www.gnu.org/software/gawk/";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.all;
    longDescription = ''
      If you are like many computer users, you would frequently like to
      make changes in various text files wherever certain patterns appear,
      or extract data from parts of certain lines while discarding the
      rest. To write a program to do this in a language such as C or Pascal
      is a time-consuming inconvenience that may take many lines of code.
      The job is easy with awk, especially the GNU implementation: gawk.
      This is a curated version pinned to 5.3.1 from nixos-24.11.
    '';
  };
})
