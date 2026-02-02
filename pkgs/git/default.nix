{ lib, git }:

git.overrideAttrs (oldAttrs: {
  pname = "curated-git";
  version = "2.47.2";
  
  meta = with lib; {
    description = "Distributed version control system (curated)";
    homepage = "https://git-scm.com/";
    license = licenses.gpl2Only;
    maintainers = [ ];
    platforms = platforms.all;
    longDescription = ''
      Git is a free and open source distributed version control system
      designed to handle everything from small to very large projects with
      speed and efficiency. This is a curated version pinned to 2.47.2
      from nixos-24.11.
    '';
  };
})
