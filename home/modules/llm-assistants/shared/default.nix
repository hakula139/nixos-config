# ==================================================================================================
# Shared LLM Assistant Modules
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  corpHosts,
  modelCatalog,
  repoLib,
  secretPath,
  ...
}:

let
  # ------------------------------------------------------------------------------------------------
  # Instructions and agent roles
  # ------------------------------------------------------------------------------------------------
  promptFragments = import ./prompt-fragments;
  roles = import ./agent-roles {
    inherit promptFragments;
  };
  toLine = text: lib.replaceStrings [ "\n" ] [ " " ] (lib.trim text);
  agentRoles = lib.mapAttrs (_: role: role // { description = toLine role.description; }) roles;

  # ------------------------------------------------------------------------------------------------
  # Profiles and gateway
  # ------------------------------------------------------------------------------------------------
  profileDefinitions = repoLib.llmAssistants.mkProfileDefinitions {
    inherit lib modelCatalog corpHosts;
  };

  corpGateway = profileDefinitions.providers.corp-gateway;

  gatewayFor = client: {
    inherit (corpGateway) baseUrl;
    tokenFile = secretPath (corpGateway.tokenSecretFor client);
    caFile = secretPath corpGateway.caSecret;
  };

  # ------------------------------------------------------------------------------------------------
  # Hooks
  # ------------------------------------------------------------------------------------------------
  fileFormatter = lib.getExe pkgs.file-formatter;

  timeouts = {
    modelConnect = 5;
    modelCall = 90;
    # A hook outlives its model calls by this much, so it can still report one that timed out.
    modelHookMargin = 10;
    tool = 10;
    # Auto-format runs the repository's gate, and a first run may install hook environments.
    postEdit = 120;
  };

  # ------------------------------------------------------------------------------------------------
  # Model calls
  # ------------------------------------------------------------------------------------------------
  mkModelCall =
    {
      assistant,
      timeout ? timeouts.modelCall,
    }:
    import ./model-call {
      inherit
        pkgs
        lib
        assistant
        repoLib
        ;
      timeouts = timeouts // {
        modelCall = timeout;
      };
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
    instructions = import ../instructions {
      inherit promptFragments;
      devkitSource = inputs.devkit;
    };
    agentRoleOptions = import ./agent-roles/options.nix {
      inherit lib agentRoles;
    };

    # ----------------------------------------------------------------------------------------------
    # Preferences
    # ----------------------------------------------------------------------------------------------
    preferences = import ./preferences;

    # ----------------------------------------------------------------------------------------------
    # MCP servers
    # ----------------------------------------------------------------------------------------------
    mcp = import ./mcp {
      inherit
        config
        pkgs
        lib
        corpGateway
        corpHosts
        repoLib
        secretPath
        ;
    };

    mcpSecrets = import ./mcp/secrets.nix;

    # ----------------------------------------------------------------------------------------------
    # Permissions
    # ----------------------------------------------------------------------------------------------
    permissions = repoLib.llmAssistants.mkPermissions {
      inherit corpHosts;
    };

    # ----------------------------------------------------------------------------------------------
    # Hooks and notifications
    # ----------------------------------------------------------------------------------------------
    mkHooks = import ./hooks {
      inherit
        pkgs
        lib
        modelCatalog
        promptFragments
        fileFormatter
        timeouts
        repoLib
        mkModelCall
        ;
      inherit (config.xdg) dataHome;
    };

    inherit fileFormatter mkModelCall;

    notify = import ./notify {
      inherit pkgs lib repoLib;
    };

    # ----------------------------------------------------------------------------------------------
    # Auth profiles
    # ----------------------------------------------------------------------------------------------
    inherit profileDefinitions;

    anthropicProfiles = import ./anthropic-profiles {
      inherit lib secretPath;
      inherit (profileDefinitions) providers;
    };

    mkProfileSwitch = import ./profile-switch {
      inherit pkgs lib repoLib;
    };
  };
}
