# ==============================================================================
# Nix Daemon Proxy
# ==============================================================================

{
  config,
  pkgs,
  lib,
  proxyLib,
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
    + proxyLib.mkProxyEnvFileScript {
      proxyCfg = cfg;
      dest = envFile;
    }
  );
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.nix-daemon.proxy = proxyLib.mkProxyOptions "the Nix daemon";

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    # Render the EnvironmentFile from the decrypted secret at boot so credentials
    # never enter the Nix store. Ordered before nix-daemon; the After= on the
    # agenix unit is a no-op when secrets install via activation script instead.
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
