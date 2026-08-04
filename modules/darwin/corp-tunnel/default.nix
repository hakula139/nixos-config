# ==============================================================================
# Corporation Network Tunnel
# ==============================================================================

{
  config,
  pkgs,
  lib,
  corpHosts,
  ...
}:

let
  cfg = config.hakula.services.corpTunnel;

  userName = config.hakula.user.name;
  homeDir = config.users.users.${userName}.home;

  gatewayHost = corpHosts.llmGateway;
  localPort = 8443;

  # Match on the owner prefix, not the full marker: renaming this module must
  # still clean up entries an earlier generation wrote.
  hostsOwner = "# nixos-config:";
  hostsEntry = "127.0.0.1 ${gatewayHost} ${hostsOwner} corp-tunnel";

  tunnelScript = pkgs.writeShellScript "corp-tunnel" ''
    set -euo pipefail

    exec ${lib.getExe' pkgs.openssh "ssh"} \
      -N \
      -o BatchMode=yes \
      -o ConnectTimeout=10 \
      -o ExitOnForwardFailure=yes \
      -o ForwardAgent=no \
      -o ServerAliveInterval=30 \
      -L 127.0.0.1:${toString localPort}:${gatewayHost}:443 \
      Hakula-Work
  '';
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.corpTunnel = {
    enable = lib.mkEnableOption "corp LLM gateway tunnel through Tailscale";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkMerge [
    # Rewrite unconditionally: disabling the module must stop resolving the
    # gateway to a loopback port that no longer forwards.
    {
      system.activationScripts.postActivation.text = lib.mkAfter ''
        hostsTmp=$(mktemp)
        grep -vF ${lib.escapeShellArg "${gatewayHost} ${hostsOwner}"} /etc/hosts >"$hostsTmp" || true
        ${lib.optionalString cfg.enable ''
          printf '%s\n' ${lib.escapeShellArg hostsEntry} >>"$hostsTmp"
        ''}
        install -m 0644 -o root -g wheel "$hostsTmp" /etc/hosts
        rm -f "$hostsTmp"
      '';
    }

    (lib.mkIf cfg.enable {
      launchd.daemons.corp-tunnel.serviceConfig = {
        ProgramArguments = [
          (lib.getExe pkgs.socat)
          "TCP-LISTEN:443,bind=127.0.0.1,reuseaddr,fork"
          "TCP:127.0.0.1:${toString localPort}"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
        ThrottleInterval = 30;
        StandardOutPath = "/var/log/corp-tunnel.log";
        StandardErrorPath = "/var/log/corp-tunnel.log";
      };

      home-manager.users.${userName} = {
        hakula.llm-assistants.proxy.noProxy = [ gatewayHost ];

        launchd.agents.corp-tunnel = {
          enable = true;
          config = {
            Label = "com.hakula.corp-tunnel";
            ProgramArguments = [ "${tunnelScript}" ];
            RunAtLoad = true;
            KeepAlive.SuccessfulExit = false;
            ProcessType = "Background";
            ThrottleInterval = 30;
            StandardOutPath = "${homeDir}/Library/Logs/corp-tunnel.log";
            StandardErrorPath = "${homeDir}/Library/Logs/corp-tunnel.log";
          };
        };
      };
    })
  ];
}
