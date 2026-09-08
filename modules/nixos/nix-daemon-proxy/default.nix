# ==============================================================================
# Nix Daemon Proxy
# ==============================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  ...
}:

let
  cfg = config.hakula.nix-daemon.proxy;

  envFile = "/run/nix-daemon-proxy/env";

  renderScript = pkgs.writeShellScript "nix-daemon-proxy-env" (
    ''
      set -euo pipefail
      install -d -m 0700 "$(dirname ${lib.escapeShellArg envFile})"
    ''
    + repoLib.proxy.mkProxyEnvFileScript {
      proxyCfg = cfg;
      dest = envFile;
    }
  );
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.nix-daemon.proxy = repoLib.proxy.mkProxyOptions "the Nix daemon";

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    systemd.services.nix-daemon-proxy-env = {
      description = "Render nix-daemon HTTP proxy environment file";
      before = [ "nix-daemon.service" ];
      requiredBy = [ "nix-daemon.service" ];
      after = [ "agenix-install-secrets.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = renderScript;
      };
    };

    systemd.services.nix-daemon.serviceConfig.EnvironmentFile = envFile;
  };
}
