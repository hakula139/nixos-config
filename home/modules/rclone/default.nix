# ==============================================================================
# Rclone Cloud Mounts
# ==============================================================================

{
  config,
  pkgs,
  lib,
  secretPath,
  ...
}:

let
  cfg = config.hakula.rclone;
  rclone = lib.getExe config.programs.rclone.package;
  configFile = secretPath "rclone/config";
  mountRoot = "${config.home.homeDirectory}/Cloud";
  stateDir = "${config.xdg.stateHome}/rclone";
  logDir = "${config.home.homeDirectory}/Library/Logs/rclone";
  socketPath = name: "${stateDir}/${name}.sock";

  refresh = pkgs.writers.writeNuBin "rclone-refresh" {
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [ config.programs.rclone.package ])
    ];
  } (builtins.readFile ./refresh.nu);

  agents = lib.concatMapAttrs (name: mount: {
    "rclone-mount-${name}" = {
      enable = true;
      config = {
        ProgramArguments = [
          rclone
          "nfsmount"
          mount.remote
          "${mountRoot}/${name}"
          "--config"
          configFile
          "--addr"
          "127.0.0.1:0"
          "--cache-dir"
          "${config.xdg.cacheHome}/rclone/${name}"
          "--vfs-cache-mode"
          mount.cacheMode
          "--vfs-cache-max-age"
          (if mount.cacheMode == "writes" then "0s" else "1h")
          "--vfs-cache-poll-interval"
          "1s"
          "--vfs-write-back"
          "1s"
          "--dir-cache-time"
          "1h"
          "--poll-interval"
          "0"
          "-o"
          "actimeo=1"
          "--rc"
          "--rc-addr"
          "unix://${socketPath name}"
          "--rc-no-auth"
        ];
        EnvironmentVariables.PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
        RunAtLoad = true;
        KeepAlive.SuccessfulExit = false;
        ThrottleInterval = 30;
        Umask = 63;
        StandardOutPath = "${logDir}/${name}.log";
        StandardErrorPath = "${logDir}/${name}.log";
      };
    };

    "rclone-refresh-${name}" = {
      enable = true;
      config = {
        ProgramArguments = [
          (lib.getExe refresh)
          (socketPath name)
        ];
        StartInterval = cfg.refreshInterval;
        Umask = 63;
        StandardOutPath = "${logDir}/${name}-refresh.log";
        StandardErrorPath = "${logDir}/${name}-refresh.log";
      };
    };
  }) cfg.mounts;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.rclone = {
    enable = lib.mkEnableOption "rclone NFS mounts on macOS";

    refreshInterval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Seconds between recursive background directory refreshes";
    };

    mounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            remote = lib.mkOption {
              type = lib.types.str;
              description = "Remote and path from the agenix-managed rclone config";
              example = "b2:bucket";
            };

            cacheMode = lib.mkOption {
              type = lib.types.enum [
                "writes"
                "full"
              ];
              default = "writes";
              description = "Use writes for remotes without reliable change fingerprints";
            };
          };
        }
      );
      default = { };
      description = "Cloud mounts under ~/Cloud, keyed by directory name";
    };
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isDarwin;
        message = "hakula.rclone requires macOS.";
      }
    ];

    hakula.secrets.required."rclone/config" = { };
    programs.rclone.enable = true;
    home.sessionVariables.RCLONE_CONFIG = configFile;
    launchd.agents = agents;

    home.activation.rcloneDirectories =
      lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "writeBoundary" ]
        ''
          run install -d -m 0700 ${
            lib.escapeShellArgs [
              stateDir
              logDir
            ]
          }
          run mkdir -p ${
            lib.escapeShellArgs (
              [ mountRoot ] ++ lib.mapAttrsToList (name: _: "${mountRoot}/${name}") cfg.mounts
            )
          }
        '';
  };
}
