# ==================================================================================================
# LLM Assistant Permissions
# ==================================================================================================

{
  config,
  lib,
  corpHosts,
  ...
}:

let
  cfg = config.hakula.llm-assistants;
in
{
  config = lib.mkIf cfg.enable {
    agents.permissions = {
      ownRepositories = [
        "github.com/hakulab"
        "github.com/hakula139"
        corpHosts.gitlab
      ];

      gateCommands = [
        {
          command = "nixboot";
          reason = "Changes the boot configuration.";
        }
        {
          command = "nixdp";
          reason = "Deploys host configurations.";
        }
        {
          command = "nixroll";
          reason = "Switches system configuration.";
        }
        {
          command = "nixsw";
          reason = "Switches system configuration.";
        }
        {
          command = "nixtest";
          reason = "Switches system configuration.";
        }
      ];
    };
  };
}
