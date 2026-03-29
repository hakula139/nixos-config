# ==============================================================================
# Codex Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  secrets,
  isNixOS ? false,
  ...
}:

let
  cfg = config.hakula.codex;
  instructions = import ../shared/instructions;
  agentRoleOptions = import ../shared/agent-roles/options.nix { inherit lib; };
  mcpOptions = import ../shared/mcp/options.nix { inherit lib; };
  codexMcpServers = [
    "context7"
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
  options.hakula.codex = {
    enable = lib.mkEnableOption "OpenAI Codex CLI";

    agents = {
      enabledAgents = agentRoleOptions.mkEnabledAgentsOption {
        description = "Custom agents to enable";
      };
    };

    mcp = {
      enabledServers = mcpOptions.mkEnabledServersOption {
        names = codexMcpServers;
        default = codexMcpServers;
        description = "MCP servers to enable";
      };
    };

    proxy = (import ../shared/proxy.nix { inherit lib; }).mkProxyOptions "Codex";
  };

  config = lib.mkIf cfg.enable (
    let
      notify = import ../shared/notify.nix { inherit pkgs lib; };

      agents = import ./agents.nix {
        inherit lib pkgs;
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

      codexPkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;

      proxyUrl =
        if cfg.proxy.secretUrlFile != null then
          "$(cat ${lib.escapeShellArg cfg.proxy.secretUrlFile})"
        else
          lib.escapeShellArg cfg.proxy.url;
      noProxy = lib.escapeShellArg (lib.concatStringsSep "," cfg.proxy.noProxy);

      proxyRunScript = ''
        export HTTP_PROXY=${proxyUrl}
        export HTTPS_PROXY=${proxyUrl}
        export NO_PROXY=${noProxy}
      '';

      codexBin =
        if cfg.proxy.enable then
          pkgs.symlinkJoin {
            # Keep codex version in the derivation name so Home Manager
            # detects this as a modern codex and renders config.toml.
            name = "codex-${codexPkg.version}";
            paths = [ codexPkg ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/codex \
                --run ${lib.escapeShellArg proxyRunScript}
            '';
          }
        else
          codexPkg;
    in
    lib.mkMerge [
      mcp.secrets
      {
        # ----------------------------------------------------------------------
        # Program configuration
        # ----------------------------------------------------------------------
        programs.codex = {
          enable = true;
          package = codexBin;

          # --------------------------------------------------------------------
          # AGENTS.md
          # --------------------------------------------------------------------
          custom-instructions = instructions.codex;

          # --------------------------------------------------------------------
          # Settings
          # --------------------------------------------------------------------
          settings = {
            # ------------------------------------------------------------------
            # Model
            # ------------------------------------------------------------------
            model = "gpt-5.4";
            model_reasoning_effort = "xhigh";
            personality = "pragmatic";

            # ------------------------------------------------------------------
            # Execution
            # ------------------------------------------------------------------
            approval_policy = "never";
            sandbox_mode = "danger-full-access";
            shell_environment_policy = {
              "inherit" = "all";
            };

            # ------------------------------------------------------------------
            # Project context
            # ------------------------------------------------------------------
            project_doc_fallback_filenames = [ "CLAUDE.md" ];

            # ------------------------------------------------------------------
            # History / memory
            # ------------------------------------------------------------------
            history = {
              persistence = "save-all";
              max_bytes = 268435456; # 256 MB
            };

            memories = {
              generate_memories = true;
              use_memories = true;
              no_memories_if_mcp_or_web_search = true;
              min_rollout_idle_hours = 24;
              max_rollouts_per_startup = 6;
              max_raw_memories_for_consolidation = 50;
            };

            # ------------------------------------------------------------------
            # Tools / search
            # ------------------------------------------------------------------
            web_search = "live";
            tools = {
              view_image = true;
              web_search.context_size = "high";
            };

            # ------------------------------------------------------------------
            # Agents
            # ------------------------------------------------------------------
            agents = agents.settings;

            # ------------------------------------------------------------------
            # MCP servers
            # ------------------------------------------------------------------
            mcp_servers = builtins.listToAttrs (
              map (s: {
                name = mcpOptions.serverDisplayNames.${s};
                value.command = mcp.servers.${s}.command;
              }) cfg.mcp.enabledServers
            );

            # ------------------------------------------------------------------
            # Skills
            # ------------------------------------------------------------------
            skills.bundled.enabled = true;

            # ------------------------------------------------------------------
            # Apps
            # ------------------------------------------------------------------
            apps = {
              _default = {
                enabled = true;
                destructive_enabled = true;
                open_world_enabled = true;
              };
            };

            # ------------------------------------------------------------------
            # Interface
            # ------------------------------------------------------------------
            notify = [
              "${notify.mkProjectNotifyScript}"
              "Codex"
              "Response complete"
            ];

            tui = {
              status_line = [
                "current-dir"
                "git-branch"
                "model-with-reasoning"
                "context-used"
                "five-hour-limit"
                "weekly-limit"
              ];
            };

            # ------------------------------------------------------------------
            # Features
            # ------------------------------------------------------------------
            suppress_unstable_features_warning = true;
            features = {
              apply_patch_freeform = true;
              apps = true;
              child_agents_md = true;
              code_mode = true;
              memories = true;
              multi_agent = true;
              plugins = true;
              shell_snapshot = true;
              unified_exec = true;
            };
          };
        };

        # ----------------------------------------------------------------------
        # Legacy cleanup
        # ----------------------------------------------------------------------
        home.activation.codexLegacySkillsCleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          skillsDir="$HOME/.agents/skills"

          if [[ -d "$skillsDir" ]]; then
            for entry in "$skillsDir"/*; do
              [[ -L "$entry" ]] && rm "$entry"
            done
          fi
        '';
      }
    ]
  );
}
