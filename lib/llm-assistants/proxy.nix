# ==============================================================================
# Proxy Options
# ==============================================================================

{ lib }:

{
  mkProxyOptions = name: {
    enable = lib.mkEnableOption "HTTP proxy for ${name}";

    url = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:7897";
      description = "HTTP proxy URL for ${name}. Ignored when secretUrlFile is set.";
    };

    secretUrlFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to a file containing the proxy URL (for secret-based proxy configuration). Overrides url when set.";
    };

    noProxy = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "localhost"
        "127.0.0.1"
        "10.*"
      ];
      description = "Domains to bypass the proxy";
    };
  };

  mkProxyScript =
    proxyCfg:
    let
      proxyUrl =
        if proxyCfg.secretUrlFile != null then
          "$(cat ${lib.escapeShellArg proxyCfg.secretUrlFile})"
        else
          lib.escapeShellArg proxyCfg.url;
      noProxy = lib.escapeShellArg (lib.concatStringsSep "," proxyCfg.noProxy);
    in
    ''
      export HTTP_PROXY=${proxyUrl}
      export HTTPS_PROXY=${proxyUrl}
      export NO_PROXY=${noProxy}
      export http_proxy=${proxyUrl}
      export https_proxy=${proxyUrl}
      export no_proxy=${noProxy}
    '';
}
