{
  config,
  pkgs,
  lib,
  inputs,
  secrets,
  isNixOS ? false,
  ...
}:

# ==============================================================================
# Codex Configuration
# ==============================================================================

let
  cfg = config.hakula.codex;
  instructions = import ../lib/instructions;
  agentRoleOptions = import ../lib/agent-roles/options.nix { inherit lib; };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.codex = {
    enable = lib.mkEnableOption "OpenAI Codex CLI";

    agents = {
      enabledAgents = agentRoleOptions.mkEnabledAgentsOption {
        description = "List of custom Codex agent roles to enable";
      };
    };

    proxy = (import ../lib/proxy.nix { inherit lib; }).mkProxyOptions "Codex";
  };

  config = lib.mkIf cfg.enable (
    let
      notify = import ../notify { inherit pkgs lib; };

      agents = import ./agents.nix {
        inherit lib pkgs;
        inherit (cfg.agents) enabledAgents;
      };

      mcp = import ../mcp {
        inherit
          config
          pkgs
          lib
          secrets
          isNixOS
          ;
      };

      skills = import ./skills.nix { inherit lib inputs; };

      codexPkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
      noProxy = lib.concatStringsSep "," cfg.proxy.noProxy;

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
                --set HTTP_PROXY ${lib.escapeShellArg cfg.proxy.url} \
                --set HTTPS_PROXY ${lib.escapeShellArg cfg.proxy.url} \
                --set NO_PROXY ${lib.escapeShellArg noProxy}
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
            model_reasoning_effort = "high";
            plan_mode_reasoning_effort = "high";
            model_verbosity = "high";
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

            # ------------------------------------------------------------------
            # Agents
            # ------------------------------------------------------------------
            agents = agents.settings;

            # ------------------------------------------------------------------
            # Skills
            # ------------------------------------------------------------------
            skills = {
              bundled = {
                enabled = true;
              };
              config = skills.configEntries;
            };

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
            # Tools / search
            # ------------------------------------------------------------------
            web_search = "live";
            tools = {
              view_image = true;
              web_search = {
                context_size = "high";
              };
            };

            # ------------------------------------------------------------------
            # Notifications
            # ------------------------------------------------------------------
            notify = [
              "${notify.mkProjectNotifyScript}"
              "Codex"
              "Response complete"
            ];

            # ------------------------------------------------------------------
            # MCP servers
            # ------------------------------------------------------------------
            mcp_servers = {
              Context7.command = mcp.servers.context7.command;
              DeepWiki.command = mcp.servers.deepwiki.command;
              Fetcher.command = mcp.servers.fetcher.command;
              Filesystem.command = mcp.servers.filesystem.command;
              Git.command = mcp.servers.git.command;
              GitHub.command = mcp.servers.github.command;
            };
          };
        };

        # ----------------------------------------------------------------------
        # Skills
        # ----------------------------------------------------------------------
        home.activation.codexSkills = skills.activation;
      }
    ]
  );
}
