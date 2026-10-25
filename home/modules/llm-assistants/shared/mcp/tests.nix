# ==================================================================================================
# MCP Launcher Tests
# ==================================================================================================

{
  pkgs,
}:

let
  inherit (pkgs) lib;

  recorder = pkgs.writeShellScriptBin "npx" ''
    printf '%s\n' "$@"
  '';

  browser = pkgs.writeShellScriptBin "chromium" ''
    exit 1
  '';

  launcher =
    isDarwin:
    (import ./default.nix {
      config = { };
      pkgs = pkgs // {
        nodejs_24 = recorder;
        browser-tools.chromium = browser;
        stdenv = pkgs.stdenv // {
          inherit isDarwin;
        };
      };
      inherit lib;
      corpGateway = { };
      corpHosts = {
        gitlabUrl = "https://example.com";
        wikiUrl = "https://example.com";
      };
      clearProxyEnv = "";
      secretPath = name: "/unused/${name}";
    }).servers.chromeDevtools.command;

  expected =
    isDarwin:
    pkgs.writeText "chrome-devtools-argv" (
      lib.concatStringsSep "\n" (
        [
          "-y"
          "chrome-devtools-mcp"
          "--executable-path=${lib.getExe browser}"
        ]
        ++ lib.optionals (!isDarwin) [ "--headless" ]
        ++ [
          "--isolated"
          "argument with spaces"
        ]
      )
      + "\n"
    );
in
pkgs.runCommand "mcp-launcher-tests" { } ''
  ${launcher true} 'argument with spaces' > darwin-argv
  diff -u ${expected true} darwin-argv

  ${launcher false} 'argument with spaces' > linux-argv
  diff -u ${expected false} linux-argv

  touch "$out"
''
