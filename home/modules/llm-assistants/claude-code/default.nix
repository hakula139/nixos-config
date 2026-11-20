# ==================================================================================================
# Claude Code Configuration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  modelCatalog,
  repoLib,
  enableDevToolchains,
  ...
}:

let
  inherit (shared) agentRoleOptions instructions;
  inherit (repoLib.llmAssistants) mcpOptions;

  cfg = config.hakula.claude-code;
  shared = config.lib.llmAssistants;

  mcp = import ./mcp.nix {
    inherit pkgs shared mcpOptions;
    enabledServers = mcpOptions.computeEnabledServers cfg.mcp;
  };

  # `--mcp-config` is variadic, so only the `=` form keeps it from swallowing the prompt.
  mcpFlag = "--mcp-config=${mcp.configFile}";

  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      modelCatalog
      shared
      mcpFlag
      ;
    inherit (cfg.agents) enabledAgents;
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.claude-code = {
    auth = profiles.options;

    agents = {
      enabledAgents = agentRoleOptions.mkEnabledAgentsOption {
        description = "Custom agents to enable";
      };
    };

    mcp = mcpOptions.mkMcpOptions { names = mcpOptions.commonServerNames; };
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf config.hakula.llm-assistants.enable (
    let
      json = pkgs.formats.json { };

      # --------------------------------------------------------------------------------------------
      # Module imports
      # --------------------------------------------------------------------------------------------
      hooks = import ./hooks {
        inherit pkgs lib shared;
        inherit (cfg.auth) enableCorpGateway;
      };

      permissionSettings = import ./permissions {
        inherit lib shared;
      };

      plugins = import ./plugins.nix {
        inherit lib enableDevToolchains;
      };

      statusLine = import ./scripts/statusline {
        inherit
          pkgs
          lib
          modelCatalog
          repoLib
          ;
      };

      # --------------------------------------------------------------------------------------------
      # Package wrapper
      # --------------------------------------------------------------------------------------------
      wrapArgs = profiles.wrapArgs ++ repoLib.proxy.mkProxyWrapArgs config.hakula.llm-assistants.proxy;

      claudeCodeBin = repoLib.wrapPackage {
        inherit pkgs wrapArgs;
        pkg = pkgs.claude-code;
        name = "claude-code-${pkgs.claude-code.version}";
        bin = "claude";
        envVars = {
          # Restores the upstream default, since nixpkgs narrows it to `system`, which loads only a
          # few Keychain roots in macOS SSH sessions.
          CLAUDE_CODE_CERT_STORE = "bundled,system";

          # The marketplaces are declared in settings, so the built-in snapshot install duplicates
          # their clone and fails when `downloads.claude.ai` is unreachable.
          CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL = "1";
        };
      };

      # --------------------------------------------------------------------------------------------
      # Configuration files
      # --------------------------------------------------------------------------------------------
      settingsJson = json.generate "claude-code-settings.json" (
        import ./settings.nix {
          inherit
            shared
            hooks
            permissionSettings
            plugins
            ;
          profileSettings = profiles.settings;
        }
        // {
          "$schema" = "https://json.schemastore.org/claude-code-settings.json";
        }
      );

      # Editor file watchers resolve symlinks and watch the parent directory, which must not be
      # /nix/store itself.
      configFiles = pkgs.runCommand "claude-code-config" { } ''
        set -euo pipefail
        mkdir -p "$out"
        cp ${lib.escapeShellArg settingsJson} "$out/settings.json"
      '';
    in
    lib.mkMerge [
      profiles.config

      {
        # ------------------------------------------------------------------------------------------
        # Program configuration
        # ------------------------------------------------------------------------------------------
        programs.claude-code = {
          enable = true;
          package = claudeCodeBin;
        };

        # ------------------------------------------------------------------------------------------
        # Configuration files
        # ------------------------------------------------------------------------------------------
        home.file = {
          ".claude/CLAUDE.md".text = lib.concatStringsSep "\n" [
            instructions
            (builtins.readFile ./instructions.md)
          ];
          ".claude/settings.json".source = "${configFiles}/settings.json";
          ".claude/statusline-command" = {
            source = lib.getExe statusLine;
            executable = true;
          };
        };

        xdg.dataFile = hooks.dataFiles;
      }
    ]
  );
}
