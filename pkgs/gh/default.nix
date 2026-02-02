{ lib, gh }:

gh.overrideAttrs (oldAttrs: {
  pname = "curated-gh";
  version = "2.63.0";
  
  meta = with lib; {
    description = "GitHub CLI - GitHub's official command line tool (curated)";
    homepage = "https://cli.github.com/";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
    longDescription = ''
      gh is GitHub on the command line. It brings pull requests, issues,
      and other GitHub concepts to the terminal next to where you are
      already working with git and your code. This is a curated version
      pinned to 2.63.0 from nixos-24.11.
    '';
  };
})
