# ==============================================================================
# MCP Server – Filesystem
# ==============================================================================

{
  pkgs,
  lib,
  ...
}:

pkgs.buildNpmPackage rec {
  pname = "mcp-server-filesystem";
  version = "2026.6.16";

  src = pkgs.fetchFromGitHub {
    owner = "modelcontextprotocol";
    repo = "servers";
    rev = version;
    hash = "sha256-n8l4E6S4d19GQnKWO1y2De1SuHa/R8UGlb/GMR4dbMw=";
  };

  npmDepsHash = "sha256-KhlTXcS+VDSPGnEus9fA0xhIxfTGwX1Cr5hbxFvdc2k=";

  # Monorepo: build the filesystem workspace
  npmWorkspace = "src/filesystem";

  nativeBuildInputs = [ pkgs.makeBinaryWrapper ];

  # Workaround: npm v11 fires workspace build/prepare scripts during `npm ci`
  # despite --ignore-scripts, and their tsc shebangs fail in the sandbox.
  # Strip them before install, then build the target workspace manually after
  # npmConfigHook has run patchShebangs on node_modules.
  postUnpack = ''
    for pkg in source/src/*/package.json; do
      ${pkgs.jq}/bin/jq 'del(.scripts.build, .scripts.prepare)' "$pkg" > tmp
      mv tmp "$pkg"
    done
  '';

  dontNpmBuild = true;
  dontNpmPrune = true;

  preBuild = ''
    node_modules/.bin/tsc -p src/filesystem
  '';

  # npmInstallHook copies `npm pack` output which excludes workspace sources.
  # Copy them manually and create a wrapper pointing to the built entry point.
  postInstall = ''
    cp -r src "$out/lib/node_modules/@modelcontextprotocol/servers/src"
    makeWrapper "${pkgs.nodejs_24}/bin/node" "$out/bin/mcp-server-filesystem" \
      --add-flags "$out/lib/node_modules/@modelcontextprotocol/servers/src/filesystem/dist/index.js"
  '';

  meta = {
    description = "MCP server for filesystem operations";
    homepage = "https://github.com/modelcontextprotocol/servers";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "mcp-server-filesystem";
  };
}
