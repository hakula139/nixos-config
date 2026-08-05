# ==============================================================================
# MCP Server – GitHub
# ==============================================================================

{
  pkgs,
  lib,
  ...
}:

let
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  version = "1.8.0";
  baseUrl = "https://github.com/github/github-mcp-server/releases/download/v${version}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/github-mcp-server_Darwin_arm64.tar.gz";
      hash = "sha256-HanP8kkPKQji/QUeCQxcB5LNRHc+4ZW4WtD1SdPENdA=";
    };
    x86_64-linux = {
      url = "${baseUrl}/github-mcp-server_Linux_x86_64.tar.gz";
      hash = "sha256-snVJIa7BsTArGacVMdJtJC7w5/HgVpa4REvqtafmHVs=";
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

  nativeBuildInputs = lib.optionals isLinux [ pkgs.autoPatchelfHook ];
  buildInputs = lib.optionals isLinux [ pkgs.stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -D -m 0755 github-mcp-server $out/bin/mcp-server-github
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
