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
  formatter = pkgs.file-formatter.override { inherit enableDevToolchains; };
  fileFormatter = lib.getExe formatter;

  promptFragments = import ./prompt-fragments;
  agentRoles = import ./agent-roles { inherit (promptFragments) readPrompt; };

  profileDefinitions = repoLib.llmAssistants.mkProfileDefinitions {
    inherit lib modelCatalog corpHosts;
  };

  corpGateway = profileDefinitions.providers.corp-gateway;

  gatewayFor = client: {
    inherit (corpGateway) baseUrl;
    tokenFile = secretPath (corpGateway.tokenSecretFor client);
    caFile = secretPath corpGateway.caSecret;
  };

  timeouts = {
    modelConnect = 5;
    modelCall = 90;
    # A hook outlives its model calls by this much, so it can still report one that timed out.
    modelHookMargin = 10;
    tool = 10;
    # Auto-format runs `cargo clippy`, which may rebuild the crate after an edit.
    postEdit = 120;
  };

  mkNuCommand = import ./nu-command { inherit pkgs lib; };

  mkModelCall =
    assistant:
    import ./model-call {
      inherit
        pkgs
        lib
        assistant
        mkNuCommand
        timeouts
        ;
      gateway = gatewayFor assistant;
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
        corpGateway
        ;
    };

    mcpSecrets = import ./mcp/secrets.nix;

    # ----------------------------------------------------------------------------------------------
    # Hooks and notifications
    # ----------------------------------------------------------------------------------------------
    mkHooks = import ./hooks {
      inherit
        pkgs
        lib
        modelCatalog
        fileFormatter
        timeouts
        mkNuCommand
        mkModelCall
        ;
      inherit (config.xdg) dataHome;
      inherit (promptFragments) readPrompt;
    };

    inherit mkModelCall;

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
