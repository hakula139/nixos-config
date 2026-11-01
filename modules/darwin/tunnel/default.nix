# ==================================================================================================
# Network Tunnel
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  corpHosts,
  ...
}:

let
  cfg = config.hakula.services.tunnel;

  userName = config.hakula.user.name;
  homeDir = config.users.users.${userName}.home;

  gatewayHost = corpHosts.llmGateway;
  localPort = 8443;

  hostsScript = pkgs.writers.writeNu "tunnel-hosts" (builtins.readFile ./hosts.nu);

  controlPackage = pkgs.writers.writeNuBin "tunnel" {
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [
        pkgs.coreutils
        config.services.tailscale.package
      ])

      "--add-flag"
      "--user-name"

      "--add-flag"
      userName
    ];
  } (builtins.readFile ./control.nu);

  tunnelScript = pkgs.writeShellScript "tunnel" ''
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
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.services.tunnel = {
    enable = lib.mkEnableOption "LLM gateway tunnel through Tailscale";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkMerge [
    # Rewrite unconditionally: disabling the module must stop resolving the gateway to a loopback
    # port that no longer forwards.
    {
      # --------------------------------------------------------------------------------------------
      # Hosts file
      # --------------------------------------------------------------------------------------------
      system.activationScripts.postActivation.text = lib.mkAfter ''
        hostsTmp=$(mktemp)
        ${hostsScript} /etc/hosts \
          ${lib.escapeShellArg (lib.optionalString cfg.enable gatewayHost)} >"$hostsTmp"
        install -m 0644 -o root -g wheel "$hostsTmp" /etc/hosts
        rm -f "$hostsTmp"
      '';
    }

    (lib.mkIf cfg.enable {
      # --------------------------------------------------------------------------------------------
      # Packages
      # --------------------------------------------------------------------------------------------
      environment.systemPackages = [ controlPackage ];

      # --------------------------------------------------------------------------------------------
      # Launchd daemons (macOS)
      # --------------------------------------------------------------------------------------------
      launchd.daemons.tunnel.serviceConfig = {
        ProgramArguments = [
          (lib.getExe pkgs.socat)
          "TCP-LISTEN:443,bind=127.0.0.1,reuseaddr,fork"
          "TCP:127.0.0.1:${toString localPort}"
        ];

        RunAtLoad = false;
        KeepAlive = false;
        ProcessType = "Background";
        StandardOutPath = "/var/log/tunnel.log";
        StandardErrorPath = "/var/log/tunnel.log";
      };

      home-manager.users.${userName} = {
        # ------------------------------------------------------------------------------------------
        # Assistant configuration
        # ------------------------------------------------------------------------------------------
        hakula.llm-assistants = {
          auth.enableCorpGateway = lib.mkDefault true;
          proxy.noProxy = [
            gatewayHost
          ];
        };

        # ------------------------------------------------------------------------------------------
        # Launchd agents (macOS)
        # ------------------------------------------------------------------------------------------
        launchd.agents.tunnel = {
          enable = true;
          config = {
            Label = "com.hakula.tunnel";
            ProgramArguments = [
              "${tunnelScript}"
            ];
            RunAtLoad = false;
            KeepAlive = false;
            ProcessType = "Background";
            StandardOutPath = "${homeDir}/Library/Logs/tunnel.log";
            StandardErrorPath = "${homeDir}/Library/Logs/tunnel.log";
          };
        };
      };
    })
  ];
}
