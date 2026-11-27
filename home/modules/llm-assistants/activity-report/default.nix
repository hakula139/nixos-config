# ==================================================================================================
# Activity Report
# ==================================================================================================

{
  config,
  lib,
  inputs,
  hostType,
  ...
}:

{
  imports = [
    inputs.agents-nix.homeModules.activity-report
  ];

  config = lib.mkIf config.hakula.llm-assistants.enable {
    agents.activity-report = {
      enable = true;
      labels = {
        default = [ hostType ];
        projects.nixos-config = [ "personal" ];
      };
    };
  };
}
