# ==================================================================================================
# MCP Server – GitHub
# ==================================================================================================

{
  pkgs,
  lib,
}:

let
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  version = "2.1.0";
  baseUrl = "https://github.com/github/github-mcp-server/releases/download/v${version}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/github-mcp-server_Darwin_arm64.tar.gz";
      hash = "sha256-P7KTbDNBZpOosmhEKrmx6DjU+7jCpoE9inf4fDAJztY=";
    };

    x86_64-linux = {
      url = "${baseUrl}/github-mcp-server_Linux_x86_64.tar.gz";
      hash = "sha256-pEL52yh86gEAi8tV/mvAKSJwMBBGw+29Gosi1uQVeys=";
    };
  };

  platform = pkgs.stdenv.hostPlatform.system;
  source = sources.${platform} or (throw "Unsupported platform: ${platform}");
in
pkgs.stdenv.mkDerivation {
  pname = "mcp-server-github";
  inherit version;

  src = pkgs.fetchurl {
    inherit (source) url hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals isLinux [
    pkgs.autoPatchelfHook
  ];
  buildInputs = lib.optionals isLinux [
    pkgs.stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall
    install -Dm0755 github-mcp-server "$out/bin/mcp-server-github"
    runHook postInstall
  '';

  meta = {
    description = "MCP server for GitHub API operations";
    homepage = "https://github.com/github/github-mcp-server";
    license = lib.licenses.mit;
    platforms = builtins.attrNames sources;
    mainProgram = "mcp-server-github";
  };
}
