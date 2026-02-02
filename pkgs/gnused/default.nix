{ lib, gnused }:

gnused.overrideAttrs (oldAttrs: {
  pname = "curated-gnused";
  version = "4.9";
  
  meta = with lib; {
    description = "GNU sed - stream editor for filtering and transforming text (curated)";
    homepage = "https://www.gnu.org/software/sed/";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.all;
    longDescription = ''
      Sed (streams editor) isn't really a true text editor or text processor.
      Instead, it is used to filter text, i.e., it takes text input and
      performs some operation (or set of operations) on it and outputs the
      modified text. Sed is typically used for extracting part of a file
      using pattern matching and substituting multiple occurrences of a
      string within a file. This is a curated version pinned to 4.9 from
      nixos-24.11.
    '';
  };
})
