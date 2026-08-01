# ==============================================================================
# Corp Gateway Tunnel
# ==============================================================================

{
  config,
  pkgs,
  lib,
  corpDomain,
  ...
}:

let
  cfg = config.hakula.services.corpGateway;

  userName = config.hakula.user.name;
  homeDir = config.users.users.${userName}.home;

  gatewayHost = "gw.llm.${corpDomain}";
  localPort = 8443;

  tunnelScript = pkgs.writeShellScript "corp-gateway-tunnel" ''
    set -euo pipefail

    exec ${lib.getExe' pkgs.openssh "ssh"} \
      -N -T \
      -o BatchMode=yes \
      -o ConnectTimeout=10 \
      -o ExitOnForwardFailure=yes \
      -o ForwardAgent=no \
      -o ServerAliveCountMax=3 \
      -o ServerAliveInterval=30 \
      -o StrictHostKeyChecking=yes \
      -L 127.0.0.1:${toString localPort}:${gatewayHost}:443 \
      Hakula-Work
  '';
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.corpGateway = {
    enable = lib.mkEnableOption "corp gateway tunnel through Tailscale";

    endpoint = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      internal = true;
      description = "Computed local corp gateway endpoint";
    };
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkMerge [
    {
      hakula.services.corpGateway.endpoint = {
        host = gatewayHost;
        url = "https://${gatewayHost}";
      };
    }

    (lib.mkIf cfg.enable {
      launchd.daemons.corp-gateway.serviceConfig = {
        ProgramArguments = [
          (lib.getExe pkgs.socat)
          "TCP-LISTEN:443,bind=127.0.0.1,reuseaddr,fork"
          "TCP:127.0.0.1:${toString localPort}"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
        ThrottleInterval = 30;
        StandardOutPath = "/var/log/corp-gateway.log";
        StandardErrorPath = "/var/log/corp-gateway.log";
      };

      home-manager.users.${userName}.launchd.agents.corp-gateway = {
        enable = true;
        config = {
          Label = "com.hakula.corp-gateway";
          ProgramArguments = [ "${tunnelScript}" ];
          RunAtLoad = true;
          KeepAlive.SuccessfulExit = false;
          ProcessType = "Background";
          ThrottleInterval = 30;
          StandardOutPath = "${homeDir}/Library/Logs/corp-gateway.log";
          StandardErrorPath = "${homeDir}/Library/Logs/corp-gateway.log";
        };
      };

      system.activationScripts.postActivation.text = lib.mkAfter ''
        (
          set -euo pipefail
          /usr/bin/sed -i "" '/# nixos-config: corp-gateway$/d' /etc/hosts
          /usr/bin/printf '%s\n' ${lib.escapeShellArg "127.0.0.1 ${gatewayHost} # nixos-config: corp-gateway"} >>/etc/hosts
        )
      '';
    })
  ];
}
