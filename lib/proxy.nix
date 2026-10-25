# ==================================================================================================
# Proxy Helper Library
# ==================================================================================================

{
  lib,
  wrapPackage,
}:

let
  proxyVars = [
    "HTTP_PROXY"
    "HTTPS_PROXY"
    "http_proxy"
    "https_proxy"
  ];

  proxyUrlScript =
    proxyCfg:
    if proxyCfg.secretUrlFile != null then
      ''
        __proxy_url="$(cat ${lib.escapeShellArg proxyCfg.secretUrlFile})" || exit "$?"
        if [[ -z "$__proxy_url" ]]; then
          printf '%s\n' \
            ${lib.escapeShellArg "proxy: secret URL file is empty: ${proxyCfg.secretUrlFile}"} >&2
          exit 1
        fi
      ''
    else
      "__proxy_url=${lib.escapeShellArg proxyCfg.url}";

  baseNoProxy = [
    "localhost"
    "127.0.0.1"
    "10.*"
  ];

  renderNoProxy = proxyCfg: lib.concatStringsSep "," (lib.unique (baseNoProxy ++ proxyCfg.noProxy));

  mkProxyScript =
    proxyCfg:
    let
      noProxy = lib.escapeShellArg (renderNoProxy proxyCfg);
    in
    ''
      ${proxyUrlScript proxyCfg}
      export HTTP_PROXY="$__proxy_url"
      export HTTPS_PROXY="$__proxy_url"
      export NO_PROXY=${noProxy}
      export http_proxy="$__proxy_url"
      export https_proxy="$__proxy_url"
      export no_proxy=${noProxy}
    '';

  mkProxyEnvFileScript =
    {
      proxyCfg,
      dest,
    }:
    let
      noProxy = renderNoProxy proxyCfg;
    in
    ''
      ${proxyUrlScript proxyCfg}
      umask 077
      printf '%s\n' \
        "HTTP_PROXY=$__proxy_url" \
        "HTTPS_PROXY=$__proxy_url" \
        ${lib.escapeShellArg "NO_PROXY=${noProxy}"} \
        "http_proxy=$__proxy_url" \
        "https_proxy=$__proxy_url" \
        ${lib.escapeShellArg "no_proxy=${noProxy}"} \
        >${lib.escapeShellArg dest}
    '';

  wrapWithProxy =
    {
      pkgs,
      pkg,
      proxyCfg,
      name ? pkg.name,
      bin ? pkg.pname or pkg.name,
    }:
    if !proxyCfg.enable then
      pkg
    else
      let
        proxyRunScript = pkgs.writeShellScript "${bin}-proxy-env" (mkProxyScript proxyCfg);
      in
      wrapPackage {
        inherit
          pkgs
          pkg
          name
          bin
          ;
        wrapArgs = [
          "--run"
          "source ${proxyRunScript}"
        ];
      };
in
{
  inherit
    mkProxyScript
    mkProxyEnvFileScript
    proxyVars
    wrapWithProxy
    ;

  # Shell snippet that clears proxy env vars. Use in scripts that must reach the network bypassing
  # any inherited HTTP(S) proxy (e.g., mihomo's own subscription fetch, or MCP servers talking to
  # internal endpoints that do not honour NO_PROXY). Nushell callers take `proxyVars` and `hide-env`
  # instead, since `unset` has no equivalent.
  clearProxyEnv = "unset ${lib.concatStringsSep " " proxyVars}";

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
      description = "Extra domains to bypass the proxy, merged with localhost, 127.0.0.1 and 10.*";
    };
  };
}
