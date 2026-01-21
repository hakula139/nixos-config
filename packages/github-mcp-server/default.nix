{
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# GitHub MCP Server
# ==============================================================================

let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  version = "0.29.0";
  baseUrl = "https://github.com/github/github-mcp-server/releases/download/v${version}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/github-mcp-server_Darwin_arm64.tar.gz";
      hash = "sha256-/5mSea5DyMCo9A7gnMJM1beNo1E4uBoqTZhpzqsAtHs=";
    };
    x86_64-linux = {
      url = "${baseUrl}/github-mcp-server_Linux_x86_64.tar.gz";
      hash = "sha256-m6qsu0CP64OWHKvQ+2RCMXE8biht7aiB0SHngE2qa7Q=";
    };
  };

  platform = pkgs.stdenv.hostPlatform.system;
  source = sources.${platform} or (throw "Unsupported platform: ${platform}");
in
pkgs.stdenv.mkDerivation {
  pname = "github-mcp-server";
  inherit version;

  src = pkgs.fetchurl {
    inherit (source) url hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals isLinux [ pkgs.autoPatchelfHook ];
  buildInputs = lib.optionals isLinux [ pkgs.stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -D -m 0755 github-mcp-server $out/bin/github-mcp-server
    runHook postInstall
  '';

  meta = {
    description = "GitHub's official MCP Server";
    homepage = "https://github.com/github/github-mcp-server";
    license = lib.licenses.mit;
    platforms = builtins.attrNames sources;
    mainProgram = "github-mcp-server";
  };
}
