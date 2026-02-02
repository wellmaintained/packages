{ lib, findutils }:

findutils.overrideAttrs (oldAttrs: {
  pname = "curated-findutils";
  version = "4.10.0";
  
  meta = with lib; {
    description = "GNU Find Utilities - find, xargs, and locate (curated)";
    homepage = "https://www.gnu.org/software/findutils/";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.all;
    longDescription = ''
      The GNU Find Utilities are the basic directory searching utilities
      of the GNU operating system. These programs are typically used in
      conjunction with other programs to provide modular and powerful
      directory search and file locating capabilities to other commands.
      This package includes find, xargs, and locate. This is a curated
      version pinned to 4.10.0 from nixos-24.11.
    '';
  };
})
