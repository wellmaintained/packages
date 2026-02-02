{ lib, stdenv, fetchurl, unzip, autoPatchelfHook, installShellFiles }:

let
  version = "1.1.48";
  
  # Map Nix system to opencode target
  targetMap = {
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
    "x86_64-darwin" = "darwin-x64";
    "aarch64-darwin" = "darwin-arm64";
  };
  
  target = targetMap.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
  
  # Determine archive extension and hash based on platform
  isLinux = lib.hasPrefix "linux" target;
  archiveExt = if isLinux then ".tar.gz" else ".zip";
  
  # Hashes for each platform binary (v1.1.48)
  # These should be updated when version changes
  hashes = {
    "linux-x64" = "1g403v47zl1hd0im51wabis92d5yr9d1msn2izh38m116868h93m";
    "linux-arm64" = "0000000000000000000000000000000000000000000000000000";  # Needs to be fetched on aarch64
    "darwin-x64" = "0000000000000000000000000000000000000000000000000000";  # Needs to be fetched on x86_64-darwin
    "darwin-arm64" = "0000000000000000000000000000000000000000000000000000";  # Needs to be fetched on aarch64-darwin
  };
in

stdenv.mkDerivation rec {
  pname = "curated-opencode";
  inherit version;

  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-${target}${archiveExt}";
    sha256 = hashes.${target};
  };

  nativeBuildInputs = lib.optionals isLinux [ autoPatchelfHook ] ++ [ installShellFiles ];
  buildInputs = lib.optionals isLinux [ stdenv.cc.cc.lib ];

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = if isLinux then ''
    tar -xzf $src
  '' else ''
    ${unzip}/bin/unzip -q $src
  '';

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/bin
    cp opencode $out/bin/
    chmod +x $out/bin/opencode
    
    # Install shell completions if available
    # Note: opencode may generate completions at runtime
    
    runHook postInstall
  '';

  # Auto-patchelf will fix the interpreter and RPATH for Linux binaries
  autoPatchelfIgnoreMissingDeps = [
    # Some optional dependencies may be missing
  ];

  meta = with lib; {
    description = "Open source AI coding agent for the terminal (curated)";
    homepage = "https://opencode.ai/";
    license = licenses.mit;
    maintainers = [ ];
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    longDescription = ''
      OpenCode is an open source AI coding agent built for the terminal.
      It brings AI-powered development capabilities with support for
      multiple providers (Claude, OpenAI, Google, local models), LSP
      integration, and a focus on TUI experience. This is a curated
      binary distribution pinned to version ${version}.
    '';
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
