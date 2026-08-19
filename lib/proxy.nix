# ==============================================================================
# Proxy Helper Library
# ==============================================================================

{ lib }:

let
  proxyVars = [
    "HTTP_PROXY"
    "HTTPS_PROXY"
    "http_proxy"
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
    "10.*"
  ];

  renderNoProxy = proxyCfg: lib.concatStringsSep "," (lib.unique (baseNoProxy ++ proxyCfg.noProxy));

  mkProxyScript =
    proxyCfg:
    let
      proxyUrl = proxyUrlExpr proxyCfg (lib.escapeShellArg proxyCfg.url);
      noProxy = lib.escapeShellArg (renderNoProxy proxyCfg);
    in
    ''
      export HTTP_PROXY=${proxyUrl}
      export HTTPS_PROXY=${proxyUrl}
      export NO_PROXY=${noProxy}
      export http_proxy=${proxyUrl}
      export https_proxy=${proxyUrl}
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
        "HTTPS_PROXY=${proxyUrl}" \
        "NO_PROXY=${noProxy}" \
        "http_proxy=${proxyUrl}" \
        "https_proxy=${proxyUrl}" \
        "no_proxy=${noProxy}" \
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
      pkgs.symlinkJoin {
        inherit name;
        paths = [ pkg ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/${bin} \
            --run ${lib.escapeShellArg proxyRunScript}
        '';
      };
in
{
  inherit
    mkProxyScript
    mkProxyEnvFileScript
    proxyVars
    wrapWithProxy
    ;

  # Shell snippet that clears proxy env vars. Use in scripts that must reach
  # the network bypassing any inherited HTTP(S) proxy (e.g., mihomo's own
  # subscription fetch, or MCP servers talking to internal endpoints that
  # do not honour NO_PROXY). Nushell callers take `proxyVars` and `hide-env`
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
