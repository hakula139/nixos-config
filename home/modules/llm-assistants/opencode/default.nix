# ==============================================================================
# OpenCode Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  corpDomain,
  llmAssistantLib,
  proxyLib,
  secretPath,
  enableDevToolchains ? false,
  ...
}:

let
  json = pkgs.formats.json { };

  cfg = config.hakula.opencode;

  agentRoleOptions = import ../shared/agent-roles/options.nix { inherit lib; };
  inherit (llmAssistantLib) mcpOptions;
  instructions = import ../shared/instructions;

  opencodeMcpServers = mcpOptions.commonServerNames ++ [ "codex" ];

  workmuxPackage = config.hakula.workmux.package;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.opencode = {
    enable = lib.mkEnableOption "OpenCode";

    agents = {
      enabledAgents = agentRoleOptions.mkEnabledAgentsOption {
        description = "Custom agents to enable";
      };
    };

    mcp = mcpOptions.mkMcpOptions { names = opencodeMcpServers; };

    plugins = {
      bundle = lib.mkEnableOption "pre-bundled plugins (for air-gapped deployment)";

      ohMyOpenCode = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable the oh-my-opencode plugin";
      };
    };

    proxy = proxyLib.mkProxyOptions "OpenCode";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      # ------------------------------------------------------------------------
      # Module imports
      # ------------------------------------------------------------------------
      agents = import ./agents.nix {
        inherit lib;
        inherit (cfg.agents) enabledAgents;
      };

      mcp = import ./mcp.nix {
        inherit
          config
          pkgs
          lib
          llmAssistantLib
          corpDomain
          proxyLib
          secretPath
          ;
        enabledServers = mcpOptions.computeEnabledServers cfg.mcp;
      };

      # ------------------------------------------------------------------------
      # TUI config
      # ------------------------------------------------------------------------
      tuiConfigFile = json.generate "opencode-tui.json" {
        "$schema" = "https://opencode.ai/tui.json";
        keybinds = {
          input_line_home = "home";
          input_line_end = "end";
          input_select_line_home = "shift+home";
          input_select_line_end = "shift+end";
          input_buffer_home = "ctrl+home";
          input_buffer_end = "ctrl+end";
          messages_first = "<leader>home";
          messages_last = "<leader>end";
        };
      };

      # ------------------------------------------------------------------------
      # Package wrapper
      # ------------------------------------------------------------------------
      opencodePkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;

      ruffFormatScript = pkgs.writeShellScript "opencode-ruff-format" ''
        ${lib.getExe pkgs.ruff} format "$1"
        ${lib.getExe pkgs.ruff} check --fix "$1" >/dev/null 2>&1 || true
      '';

      goFormatScript = pkgs.writeShellScript "opencode-go-format" ''
        if command -v goimports >/dev/null 2>&1; then
          exec goimports -w "$1"
        fi

        exec ${lib.getExe' pkgs.go "gofmt"} -w "$1"
      '';

      opencodeBin = proxyLib.wrapWithProxy {
        inherit pkgs;
        pkg = opencodePkg;
        proxyCfg = cfg.proxy;
        name = "opencode-${opencodePkg.version}";
        bin = "opencode";
      };

      # ------------------------------------------------------------------------
      # oh-my-openagent
      # ------------------------------------------------------------------------
      ohMyOpenCodePkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.oh-my-opencode;
      ohMyOpenCodeRoot = "${ohMyOpenCodePkg}/lib/oh-my-opencode";

      pluginConfigFile = json.generate "oh-my-openagent.json" {
        git_master = {
          commit_footer = false;
          include_co_authored_by = false;
        };
      };
    in
    lib.mkMerge [
      {
        # ----------------------------------------------------------------------
        # Program configuration
        # ----------------------------------------------------------------------
        xdg.configFile = {
          "opencode/tui.json".source = tuiConfigFile;
        }
        // lib.optionalAttrs config.hakula.workmux.enable {
          "opencode/package.json".source = "${workmuxPackage.src}/resources/opencode/package.json";
          "opencode/plugins/workmux-status.ts".source =
            "${workmuxPackage.src}/resources/opencode/plugins/workmux-status.ts";
        }
        // lib.optionalAttrs cfg.plugins.ohMyOpenCode {
          "opencode/oh-my-openagent.json".source = pluginConfigFile;
        };

        programs.opencode = {
          enable = true;
          package = opencodeBin;
          context = instructions.opencode;

          # --------------------------------------------------------------------
          # Agents
          # --------------------------------------------------------------------
          inherit agents;

          # --------------------------------------------------------------------
          # Settings
          # --------------------------------------------------------------------
          settings = {
            # ------------------------------------------------------------------
            # Models
            # ------------------------------------------------------------------
            model = "openai/gpt-5.6-sol";
            small_model = "openai/gpt-5.6-luna";
            provider = {
              openai.models."gpt-5.6-sol".options = {
                reasoningEffort = "high";
                textVerbosity = "low";
              };
            };

            # ------------------------------------------------------------------
            # Permissions
            # ------------------------------------------------------------------
            permission.bash = llmAssistantLib.permissions.opencodeBash;

            # ------------------------------------------------------------------
            # MCP servers
            # ------------------------------------------------------------------
            mcp = mcp.serversConfig;

            # ------------------------------------------------------------------
            # Plugins
            # ------------------------------------------------------------------
            plugin = lib.optionals (cfg.plugins.ohMyOpenCode && !cfg.plugins.bundle) [
              "oh-my-opencode"
            ];

            # ------------------------------------------------------------------
            # Formatters
            # ------------------------------------------------------------------
            formatter = {
              nixfmt.command = [
                (lib.getExe pkgs.nixfmt)
                "$FILE"
              ];
              ruff.command = [
                "${ruffFormatScript}"
                "$FILE"
              ];
              shfmt.command = [
                (lib.getExe pkgs.shfmt)
                "-w"
                "$FILE"
              ];
              taplo = {
                command = [
                  (lib.getExe pkgs.taplo)
                  "fmt"
                  "$FILE"
                ];
                extensions = [ ".toml" ];
              };
            }
            // lib.optionalAttrs enableDevToolchains {
              gofmt.command = [
                "${goFormatScript}"
                "$FILE"
              ];
            };

            # ------------------------------------------------------------------
            # Updates
            # ------------------------------------------------------------------
            autoupdate = false;
            autoshare = false;
          };
        };
      }

      (lib.mkIf (cfg.plugins.ohMyOpenCode && cfg.plugins.bundle) {
        xdg.configFile = {
          "opencode/oh-my-opencode" = {
            source = ohMyOpenCodeRoot;
            recursive = true;
          };
          "opencode/plugins/oh-my-openagent.js".text = ''
            export { default } from "../oh-my-opencode/dist/index.js";
          '';
        };
      })
    ]
  );
}
