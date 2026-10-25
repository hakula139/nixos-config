# ==================================================================================================
# Proxy Test Fixtures
# ==================================================================================================

{
  pkgs,
}:

let
  inherit (pkgs) lib;
  inherit (import ./default.nix { inherit lib; }) proxy;

  json = pkgs.formats.json { };

  normalUrl = "http://fixture:password@proxy.example.test:8080";
  literalUrl = ''http://u:p$ss'"`touch backtick`$(touch substitution)\q@proxy.test:8'';

  cfg = {
    enable = true;
    url = normalUrl;
    secretUrlFile = null;
    noProxy = [
      "example.test"
      "localhost"
    ];
  };

  scripts = name: proxyCfg: {
    script = pkgs.writeText "${name}-proxy-script" (proxy.mkProxyScript proxyCfg);
    envFile = pkgs.writeText "${name}-proxy-env-file" (
      proxy.mkProxyEnvFileScript {
        inherit proxyCfg;
        dest = "proxy environment";
      }
    );
  };
in
json.generate "proxy-test-fixtures.json" {
  inherit normalUrl literalUrl;

  normal = scripts "normal" cfg;
  literal = scripts "literal" (cfg // { url = literalUrl; });
  empty = scripts "empty" (cfg // { url = ""; });
  secret = scripts "secret" (cfg // { secretUrlFile = "proxy secret"; });
}
