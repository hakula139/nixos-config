# ==============================================================================
# OpenCode Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  hostType,
  repoLib,
  secretPath,
  enableDevToolchains ? false,
  ...
}:

let
  cfg = config.hakula.opencode;
  shared = config.lib.llmAssistants;

  inherit (shared) agentRoleOptions instructions;
  inherit (repoLib.llmAssistants) mcpOptions;

  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      hostType
      secretPath
      ;
    inherit (shared) profileDefinitions mkProfileSwitch;
    inherit (cfg.agents) enabledAgents;
    sharedAgents = shared.agentRoles;
  };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.opencode = {
    enable = lib.mkEnableOption "OpenCode";

    auth = profiles.options;

    agents = {
      enabledAgents = agentRoleOptions.mkEnabledAgentsOption {
        description = "Custom agents to enable";
      };
    };

    mcp = mcpOptions.mkMcpOptions { names = mcpOptions.commonServerNames; };

    plugins = {
      bundle = lib.mkEnableOption "pre-bundled plugins (for air-gapped deployment)";

      ohMyOpenCode = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable the oh-my-opencode plugin";
      };
    };

    proxy = repoLib.proxy.mkProxyOptions "OpenCode";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      inherit (pkgs) workmux;

      json = pkgs.formats.json { };

      # ------------------------------------------------------------------------
      # Module imports
      # ------------------------------------------------------------------------
      agents = import ./agents.nix {
        inherit lib;
        inherit (cfg.agents) enabledAgents;
        sharedAgents = shared.agentRoles;
      };

      mcp = import ./mcp.nix {
        inherit mcpOptions;
        inherit (shared.mcp) timeouts;
        enabledServers = mcpOptions.computeEnabledServers cfg.mcp;
        mcpServers = shared.mcp.servers;
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
      # Formatters
      # ------------------------------------------------------------------------
      goFormatScript = pkgs.writeShellScript "opencode-go-format" ''
        if command -v goimports >/dev/null 2>&1; then
          exec goimports -w "$1"
        fi

        exec ${lib.getExe' pkgs.go "gofmt"} -w "$1"
      '';

      ruffFormatScript = pkgs.writeShellScript "opencode-ruff-format" ''
        ${lib.getExe pkgs.ruff} format "$1"
        ${lib.getExe pkgs.ruff} check --fix "$1" >/dev/null 2>&1 || true
      '';

      # ------------------------------------------------------------------------
      # Package wrapper
      # ------------------------------------------------------------------------
      opencodeBin = repoLib.wrapPackage {
        inherit pkgs;
        inherit (profiles) envVars;
        pkg = pkgs.opencode;
        name = "opencode-${pkgs.opencode.version}";
        bin = "opencode";
        wrapArgs = lib.optionals cfg.proxy.enable [
          "--run"
          (repoLib.proxy.mkProxyScript cfg.proxy)
        ];
      };

      # ------------------------------------------------------------------------
      # oh-my-openagent
      # ------------------------------------------------------------------------
      ohMyOpenCodeRoot = "${pkgs.oh-my-opencode}/lib/oh-my-opencode";

      pluginConfigFile = json.generate "oh-my-openagent.json" {
        git_master = {
          commit_footer = false;
          include_co_authored_by = false;
        };
      };
    in
    lib.mkMerge [
      profiles.config

      {
        # ----------------------------------------------------------------------
        # Program configuration
        # ----------------------------------------------------------------------
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
            # Permissions
            # ------------------------------------------------------------------
            permission.bash = repoLib.llmAssistants.permissions.opencodeBash;

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

        # ----------------------------------------------------------------------
        # Configuration files
        # ----------------------------------------------------------------------
        xdg.configFile = {
          "opencode/package.json".source = "${workmux.src}/resources/opencode/package.json";
          "opencode/plugins/workmux-status.ts".source =
            "${workmux.src}/resources/opencode/plugins/workmux-status.ts";
          "opencode/tui.json".source = tuiConfigFile;
        }
        // lib.optionalAttrs cfg.plugins.ohMyOpenCode {
          "opencode/oh-my-openagent.json".source = pluginConfigFile;
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
