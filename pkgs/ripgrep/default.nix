{ lib, ripgrep }:

ripgrep.overrideAttrs (oldAttrs: {
  pname = "curated-ripgrep";
  version = "14.1.1";
  
  meta = with lib; {
    description = "Fast line-oriented search tool that recursively searches directories (curated)";
    homepage = "https://github.com/BurntSushi/ripgrep";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
    longDescription = ''
      ripgrep is a line-oriented search tool that recursively searches the
      current directory for a regex pattern. By default, ripgrep respects
      .gitignore and automatically skips hidden files, directories, and
      binary files. This is a curated version pinned to 14.1.1 from
      nixos-24.11.
    '';
  };
})
