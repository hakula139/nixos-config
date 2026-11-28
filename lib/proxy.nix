# ==================================================================================================
# Proxy Helper Library
# ==================================================================================================

{
  lib,
}:

let
  defaultUrl = "http://127.0.0.1:7897";

  proxyVars = [
    "HTTP_PROXY"
    "http_proxy"
    "HTTPS_PROXY"
    "https_proxy"
  ];

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

  mkProxyWrapArgs =
    proxyCfg:
    lib.optionals proxyCfg.enable [
      "--run"
      (mkProxyScript proxyCfg)
    ];
in
{
  inherit
    defaultUrl
    mkProxyScript
    mkProxyWrapArgs
    proxyVars
    renderNoProxy
    ;

  mkProxyOptions = name: {
    enable = lib.mkEnableOption "HTTP proxy for ${name}";

    url = lib.mkOption {
      type = lib.types.str;
      default = defaultUrl;
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
