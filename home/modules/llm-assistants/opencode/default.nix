# ==============================================================================
# OpenCode Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  secrets,
  isNixOS ? false,
  enableDevToolchains ? false,
  ...
}:

let
  json = pkgs.formats.json { };

  cfg = config.hakula.opencode;
  agentRoleOptions = import ../shared/agent-roles/options.nix { inherit lib; };
  mcpOptions = import ../shared/mcp/options.nix { inherit lib; };
  proxyLib = import ../shared/proxy.nix { inherit lib; };
  instructions = import ../shared/instructions;
  opencodeMcpServers = [
    "atlassian"
    "braveSearch"
    "codex"
    "deepwiki"
    "fetcher"
    "filesystem"
    "git"
    "github"
    "gitlab"
  ];
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

    mcp = {
      enabledServers = mcpOptions.mkEnabledServersOption {
        names = opencodeMcpServers;
        description = "MCP servers to enable";
      };
      disabledServers = mcpOptions.mkDisabledServersOption {
        description = "MCP servers to disable";
      };
    };

    plugins = {
      bundle = lib.mkEnableOption "pre-bundled plugins (for air-gapped deployment)";

      ohMyOpenCode = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable the oh-my-opencode plugin";
      };
    };

    proxy = proxyLib.mkProxyOptions "OpenCode";
  };

  config = lib.mkIf cfg.enable (
    let
      # ------------------------------------------------------------------------
      # Module imports
      # ------------------------------------------------------------------------
      agents = import ./agents.nix {
        inherit lib;
        inherit (cfg.agents) enabledAgents;
      };

      mcp = import ../shared/mcp {
        inherit
          config
          pkgs
          lib
          secrets
          isNixOS
          ;
      };

      # ------------------------------------------------------------------------
      # MCP server mapping
      # ------------------------------------------------------------------------
      effectiveServers = builtins.filter (
        s: !(lib.elem s cfg.mcp.disabledServers) && (s != "codex" || config.hakula.codex.enable)
      ) cfg.mcp.enabledServers;

      mcpServersConfig = builtins.listToAttrs (
        map (s: {
          name = mcpOptions.serverDisplayNames.${s};
          value = {
            type = "local";
            command = [ mcp.servers.${s}.command ];
          };
        }) effectiveServers
      );

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

      proxyRunScript = proxyLib.mkProxyScript cfg.proxy;

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

      opencodeBin =
        if cfg.proxy.enable then
          pkgs.symlinkJoin {
            name = "opencode-${opencodePkg.version}";
            paths = [ opencodePkg ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/opencode \
                --run ${lib.escapeShellArg proxyRunScript}
            '';
          }
        else
          opencodePkg;

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
      mcp.secrets
      {
        # ----------------------------------------------------------------------
        # Program configuration
        # ----------------------------------------------------------------------
        xdg.configFile = {
          "opencode/oh-my-openagent.json".source = pluginConfigFile;
          "opencode/tui.json".source = tuiConfigFile;
        };

        programs.opencode = {
          enable = true;
          package = opencodeBin;

          # --------------------------------------------------------------------
          # AGENTS.md
          # --------------------------------------------------------------------
          rules = instructions.opencode;

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
            model = "openai/gpt-5.4";
            small_model = "openai/gpt-5.4-mini";
            provider = {
              openai.models."gpt-5.4".options = {
                reasoningEffort = "xhigh";
              };
            };

            # ------------------------------------------------------------------
            # MCP servers
            # ------------------------------------------------------------------
            mcp = mcpServersConfig;

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
