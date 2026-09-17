# ==============================================================================
# Shared LLM Assistant Modules
# ==============================================================================

{
  config,
  pkgs,
  lib,
  corpHosts,
  modelCatalog,
  repo,
  repoLib,
  secretPath,
  enableDevToolchains ? false,
  ...
}:

let
  promptFragments = import ./prompt-fragments;
  agentRoles = import ./agent-roles { inherit (promptFragments) readPrompt; };
in
{
  imports = [
    ./skills
  ];

  lib.llmAssistants = {
    # --------------------------------------------------------------------------
    # Instructions and agent roles
    # --------------------------------------------------------------------------
    inherit agentRoles;
    instructions = import ./instructions { inherit (promptFragments) readPrompt; };
    agentRoleOptions = import ./agent-roles/options.nix { inherit lib agentRoles; };

    # --------------------------------------------------------------------------
    # MCP servers
    # --------------------------------------------------------------------------
    mcp = import ./mcp {
      inherit (repoLib.proxy) clearProxyEnv;
      inherit
        config
        pkgs
        lib
        corpHosts
        secretPath
        ;
    };
    mcpSecrets = import ./mcp/secrets.nix;

    # --------------------------------------------------------------------------
    # Hooks and notifications
    # --------------------------------------------------------------------------
    mkHooks = import ./hooks {
      inherit
        pkgs
        lib
        modelCatalog
        repo
        enableDevToolchains
        ;
      inherit (promptFragments) readPrompt phrasing;
    };

    notify = import ./notify { inherit pkgs lib; };

    # --------------------------------------------------------------------------
    # Auth profiles
    # --------------------------------------------------------------------------
    profileDefinitions = repoLib.llmAssistants.mkProfileDefinitions {
      inherit lib modelCatalog corpHosts;
    };

    mkProfileSwitch = import ./profile-switch { inherit pkgs lib; };
  };
}
