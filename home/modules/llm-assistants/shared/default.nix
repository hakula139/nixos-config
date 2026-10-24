# ==================================================================================================
# Shared LLM Assistant Modules
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  corpHosts,
  modelCatalog,
  repoLib,
  secretPath,
  enableDevToolchains ? false,
  ...
}:

let
  tooling = repoLib.toolingFor pkgs;
  formatFiles = lib.getExe (tooling.mkFormatFiles { inherit enableDevToolchains; });

  promptFragments = import ./prompt-fragments;
  agentRoles = import ./agent-roles { inherit (promptFragments) readPrompt; };

  profileDefinitions = repoLib.llmAssistants.mkProfileDefinitions {
    inherit lib modelCatalog corpHosts;
  };
in
{
  imports = [
    ./skills
  ];

  lib.llmAssistants = {
    # ----------------------------------------------------------------------------------------------
    # Instructions and agent roles
    # ----------------------------------------------------------------------------------------------
    inherit agentRoles;
    instructions = import ../instructions { inherit (promptFragments) readPrompt; };
    agentRoleOptions = import ./agent-roles/options.nix { inherit lib agentRoles; };

    # ----------------------------------------------------------------------------------------------
    # Preferences
    # ----------------------------------------------------------------------------------------------
    preferences = import ./preferences;

    # ----------------------------------------------------------------------------------------------
    # MCP servers
    # ----------------------------------------------------------------------------------------------
    mcp = import ./mcp {
      inherit (repoLib.proxy) clearProxyEnv;
      inherit
        config
        pkgs
        lib
        corpHosts
        secretPath
        ;
      corpGateway = profileDefinitions.providers.corp-gateway;
    };

    mcpSecrets = import ./mcp/secrets.nix;

    # ----------------------------------------------------------------------------------------------
    # Hooks and notifications
    # ----------------------------------------------------------------------------------------------
    mkHooks = import ./hooks {
      inherit
        pkgs
        lib
        secretPath
        modelCatalog
        formatFiles
        ;
      inherit (config.xdg) dataHome;
      inherit (promptFragments) readPrompt phrasing;
      corpGateway = profileDefinitions.providers.corp-gateway;
    };

    notify = import ./notify { inherit pkgs lib; };

    # ----------------------------------------------------------------------------------------------
    # Auth profiles
    # ----------------------------------------------------------------------------------------------
    inherit profileDefinitions;

    anthropicProfiles = import ./anthropic-profiles {
      inherit lib secretPath;
      inherit (profileDefinitions) providers;
    };

    mkProfileSwitch = import ./profile-switch { inherit pkgs lib; };
  };
}
