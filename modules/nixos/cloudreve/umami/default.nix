{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Cloudreve - Umami Analytics (Download Tracking)
# ==============================================================================

let
  cfg = config.hakula.services.cloudreve;
  umamiCfg = cfg.umami;

  serviceName = "cloudreve";
  stateDir = "/var/lib/${serviceName}";
  staticsDir = "${stateDir}/data/statics";

  trackingJS = pkgs.substitute {
    src = ./tracking.js;
    substitutions = [
      "--replace-warn"
      "__WORKER_HOST__"
      umamiCfg.workerHost
    ];
  };
  trackingJSFilename = "umami-tracking.js";

  indexHTMLPatch = pkgs.writeText "umami-scripts.html" ''
    <script defer src="/${trackingJSFilename}"></script>
  '';
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.cloudreve.umami = {
    enable = lib.mkEnableOption "Umami analytics for download tracking";

    workerHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "b2.hakula.xyz";
      description = "Cloudflare Worker host for B2 downloads";
    };
  };

  config = lib.mkIf (cfg.enable && umamiCfg.enable) {
    assertions = [
      {
        assertion = umamiCfg.workerHost != null;
        message = "hakula.services.cloudreve.umami.workerHost must be set when Umami is enabled.";
      }
    ];

    systemd.services.cloudreve.preStart = lib.mkAfter ''
      if [ ! -d "${staticsDir}" ]; then
        cd "$STATE_DIRECTORY" && ./cloudreve eject
      fi

      # Inject Umami tracking script into index.html
      indexFile="${staticsDir}/index.html"
      if [ -f "$indexFile" ] && ! grep -q "${trackingJSFilename}" "$indexFile"; then
        ${pkgs.gnused}/bin/sed -i "s|</head>|  $(cat ${indexHTMLPatch})\n  </head>|" "$indexFile"
      fi
      install -m 0644 ${trackingJS} "${staticsDir}/${trackingJSFilename}"
    '';
  };
}
