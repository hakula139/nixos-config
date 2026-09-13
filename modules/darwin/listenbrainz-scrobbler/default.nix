# ==============================================================================
# ListenBrainz Scrobbler
# ==============================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  cfg = config.hakula.services.listenbrainz-scrobbler;

  userName = config.system.primaryUser;
  homeDir = config.users.users.${userName}.home;
  stateDir = "${homeDir}/Library/Application Support/listenbrainz-scrobbler";

  app =
    pkgs.python313Packages.toPythonModule
      inputs.listenbrainz-scrobbler.packages.${pkgs.stdenv.hostPlatform.system}.default;
  python = app.pythonModule;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.listenbrainz-scrobbler = {
    enable = lib.mkEnableOption "Apple Music scrobbling to ListenBrainz";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ app ];

    system.activationScripts.userLaunchd.text = lib.mkBefore ''
      install -d -o ${lib.escapeShellArg userName} -m 0700 ${lib.escapeShellArg stateDir}
    '';

    launchd.user.agents.listenbrainz-scrobbler.serviceConfig = {
      Label = "xyz.hakula.listenbrainz-scrobbler";
      # Launch Python directly so macOS attributes Music Automation to its interpreter.
      ProgramArguments = [
        python.interpreter
        "-m"
        "lb_scrobbler.cli"
        "run"
      ];
      EnvironmentVariables = {
        PYTHONPATH = python.pkgs.makePythonPath [ app ];
        PYTHONNOUSERSITE = "true";
      };
      RunAtLoad = true;
      KeepAlive.SuccessfulExit = false;
      ThrottleInterval = 30;
      ExitTimeOut = 80;
      StandardOutPath = "${stateDir}/service.log";
      StandardErrorPath = "${stateDir}/service.log";
    };
  };
}
