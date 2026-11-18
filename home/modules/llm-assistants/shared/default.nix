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
  # Prompts
  # ------------------------------------------------------------------------------------------------
  promptFragments = import ./prompt-fragments;

  # ------------------------------------------------------------------------------------------------
  # Instructions
  # ------------------------------------------------------------------------------------------------
  instructionsDir = "${config.xdg.dataHome}/llm-assistants/instructions";

  instructionSet = import ./instructions {
    inherit promptFragments;
    devkitSource = inputs.devkit.outPath;
    docsDir = instructionsDir;
  };

  # ------------------------------------------------------------------------------------------------
  # Agents
  # ------------------------------------------------------------------------------------------------
  roles = import ./agent-roles {
    inherit promptFragments;
  };

  toLine = text: lib.replaceStrings [ "\n" ] [ " " ] (lib.trim text);
  agentRoles = lib.mapAttrs (_: role: role // { description = toLine role.description; }) roles;

  # ------------------------------------------------------------------------------------------------
  # Profiles
  # ------------------------------------------------------------------------------------------------
  profileDefinitions = repoLib.llmAssistants.mkProfileDefinitions {
    inherit lib corpHosts modelCatalog;
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

  mkModelCall =
    {
      assistant,
      timeout ? timeouts.modelCall,
    }:
    import ./model-call {
      inherit
        pkgs
        lib
        repoLib
        assistant
        ;
      gateway = gatewayFor assistant;
      timeouts = timeouts // {
        modelCall = timeout;
      };
    };
in
{
  imports = [
    ./skills
  ];

  config = lib.mkMerge [
    {
      lib.llmAssistants = {
        # ------------------------------------------------------------------------------------------
        # Paths
        # ------------------------------------------------------------------------------------------
        claudeConfigDir = "${config.home.homeDirectory}/.claude";

        codexConfigDir =
          if config.home.preferXdgDirectories then
            "${config.xdg.configHome}/codex"
          else
            "${config.home.homeDirectory}/.codex";

        ompConfigDir = "${config.home.homeDirectory}/.omp/agent";

        # ------------------------------------------------------------------------------------------
        # Instructions
        # ------------------------------------------------------------------------------------------
        inherit instructionsDir;

        instructions = instructionSet.base;

        # ------------------------------------------------------------------------------------------
        # Agents
        # ------------------------------------------------------------------------------------------
        inherit agentRoles;

        agentRoleOptions = import ./agent-roles/options.nix {
          inherit lib agentRoles;
        };

        # ------------------------------------------------------------------------------------------
        # Preferences
        # ------------------------------------------------------------------------------------------
        preferences = import ./preferences;

        # ------------------------------------------------------------------------------------------
        # Profiles
        # ------------------------------------------------------------------------------------------
        inherit profileDefinitions;

        anthropicProfiles = import ./anthropic-profiles {
          inherit lib secretPath;
          inherit (profileDefinitions) providers;
        };

        mkProfileSwitch = import ./profile-switch {
          inherit pkgs lib repoLib;
        };

        # ------------------------------------------------------------------------------------------
        # Permissions
        # ------------------------------------------------------------------------------------------
        permissions = repoLib.llmAssistants.mkPermissions {
          inherit corpHosts;
        };

        # ------------------------------------------------------------------------------------------
        # MCP servers
        # ------------------------------------------------------------------------------------------
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

        # ------------------------------------------------------------------------------------------
        # Hooks
        # ------------------------------------------------------------------------------------------
        inherit fileFormatter mkModelCall;

        mkHooks = import ./hooks {
          inherit
            pkgs
            lib
            modelCatalog
            repoLib
            promptFragments
            fileFormatter
            mkModelCall
            timeouts
            ;
          inherit (config.xdg) dataHome;
        };

        notify = import ./notify {
          inherit pkgs lib repoLib;
        };
      };
    }

    (lib.mkIf config.hakula.llm-assistants.enable {
      xdg.dataFile = lib.mapAttrs' (
        name: text: lib.nameValuePair "llm-assistants/instructions/${name}" { inherit text; }
      ) instructionSet.docs;
    })
  ];
}
