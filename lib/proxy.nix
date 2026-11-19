# ==================================================================================================
# Proxy Helper Library
# ==================================================================================================

{
  lib,
}:

let
  proxyVars = [
    "HTTP_PROXY"
    "http_proxy"
    "HTTPS_PROXY"
    "https_proxy"
  ];

  proxyUrlExpr =
    proxyCfg: literalUrl:
    if proxyCfg.secretUrlFile != null then
      "$(cat ${lib.escapeShellArg proxyCfg.secretUrlFile})"
    else
      literalUrl;

  baseNoProxy = [
    "localhost"
    "127.0.0.1"
    "10.0.0.0/8"
  ];

  renderNoProxy = proxyCfg: lib.concatStringsSep "," (lib.unique (baseNoProxy ++ proxyCfg.noProxy));

  mkProxyScript =
    proxyCfg:
    let
      noProxy = lib.escapeShellArg (renderNoProxy proxyCfg);
      secretFile = lib.escapeShellArg proxyCfg.secretUrlFile;
      readUrl =
        if proxyCfg.secretUrlFile != null then
          ''
            if [ -r ${secretFile} ]; then
              proxy_url=$(cat ${secretFile})
            else
              proxy_url=
            fi''
        else
          "proxy_url=${lib.escapeShellArg proxyCfg.url}";
    in
    ''
      ${readUrl}

      if [ -n "$proxy_url" ]; then
        export HTTP_PROXY="$proxy_url"
        export http_proxy="$proxy_url"
        export HTTPS_PROXY="$proxy_url"
        export https_proxy="$proxy_url"
      fi
      unset proxy_url

      export NO_PROXY=${noProxy}
      export no_proxy=${noProxy}
    '';

  mkProxyEnvFileScript =
    {
      proxyCfg,
      dest,
    }:
    let
      proxyUrl = proxyUrlExpr proxyCfg proxyCfg.url;
      noProxy = renderNoProxy proxyCfg;
    in
    ''
      umask 077
      printf '%s\n' \
        "HTTP_PROXY=${proxyUrl}" \
        "http_proxy=${proxyUrl}" \
        "HTTPS_PROXY=${proxyUrl}" \
        "https_proxy=${proxyUrl}" \
        "NO_PROXY=${noProxy}" \
        "no_proxy=${noProxy}" \
        >${lib.escapeShellArg dest}
    '';

  mkProxyWrapArgs =
    proxyCfg:
    lib.optionals proxyCfg.enable [
      "--run"
      (mkProxyScript proxyCfg)
    ];
in
{
  inherit
    mkProxyScript
    mkProxyEnvFileScript
    mkProxyWrapArgs
    proxyVars
    ;

  # Shell snippet that clears proxy env vars. Use in scripts that must reach the network bypassing
  # any inherited HTTP(S) proxy (e.g., mihomo's own subscription fetch, or MCP servers talking to
  # internal endpoints that do not honor NO_PROXY). Nushell callers take `proxyVars` and `hide-env`
  # instead, since `unset` has no equivalent.
  clearProxyEnv = "unset ${lib.concatStringsSep " " proxyVars}";

  # Shell snippet for Node wrappers. Node's built-in fetch ignores HTTP_PROXY unless
  # NODE_USE_ENV_PROXY is set, and Node ignores CIDR entries in NO_PROXY, so this stays out of the
  # shared proxy environment.
  nodeProxyScript = "export NODE_USE_ENV_PROXY=1";

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
      default = [ ];
      description = "Extra domains to bypass the proxy, merged with localhost, 127.0.0.1 and 10.0.0.0/8";
    };
  };
}
