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
  agentRoleOptions = import ../shared/agent-roles/options.nix { inherit lib; };
  mcpOptions = import ../shared/mcp/options.nix { inherit lib; };
  proxyLib = import ../shared/proxy.nix { inherit lib; };
  instructions = import ../shared/instructions;
  codexMcpServers = [
    "atlassian"
    "braveSearch"
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
        description = "MCP servers to enable";
      };
      disabledServers = mcpOptions.mkDisabledServersOption {
        description = "MCP servers to disable";
      };
    };

    proxy = proxyLib.mkProxyOptions "Codex";
  };

  config = lib.mkIf cfg.enable (
    let
      # ------------------------------------------------------------------------
      # Module imports
      # ------------------------------------------------------------------------
      hooks = import ./hooks { inherit pkgs lib; };
      notify = import ../shared/notify.nix { inherit pkgs lib; };
      tomlFormat = pkgs.formats.toml { };

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

      # ------------------------------------------------------------------------
      # Package wrapper
      # ------------------------------------------------------------------------
      codexPkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;

      proxyRunScript = proxyLib.mkProxyScript cfg.proxy;

      codexBin =
        if cfg.proxy.enable then
          pkgs.symlinkJoin {
            # Keep codex version in the derivation name so Home Manager
            # detects this as a modern codex for config directory layout.
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

      codexSettings = {
        # ------------------------------------------------------------------
        # Model
        # ------------------------------------------------------------------
        model = "gpt-5.5";
        model_reasoning_effort = "high";
        model_verbosity = "low";
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
          disable_on_external_context = true;
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
        # Hooks
        # ------------------------------------------------------------------
        inherit hooks;

        # ------------------------------------------------------------------
        # MCP servers
        # ------------------------------------------------------------------
        mcp_servers = builtins.listToAttrs (
          map (s: {
            name = mcpOptions.serverDisplayNames.${s};
            value.command = mcp.servers.${s}.command;
          }) (builtins.filter (s: !(lib.elem s cfg.mcp.disabledServers)) cfg.mcp.enabledServers)
        );

        # ------------------------------------------------------------------
        # Skills
        # ------------------------------------------------------------------
        skills.bundled.enabled = true;

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
        # Notices
        # ------------------------------------------------------------------
        notice = {
          fast_default_opt_out = true;
        };

        # ------------------------------------------------------------------
        # Features
        # ------------------------------------------------------------------
        suppress_unstable_features_warning = true;
        features = {
          hooks = true;
          memories = true;
          prevent_idle_sleep = true;
        };
      };

      codexConfig = tomlFormat.generate "codex-config" codexSettings;
      codexConfigDir =
        if config.home.preferXdgDirectories then
          "${config.xdg.configHome}/codex"
        else
          "${config.home.homeDirectory}/.codex";
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
          settings = { };
        };

        # ----------------------------------------------------------------------
        # Mutable config
        # ----------------------------------------------------------------------
        # Codex writes project trust and hook review state back into config.toml.
        # Keep the live file writable, preserving those tables across rebuilds.
        home.activation.codexMutableConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          configDir=${lib.escapeShellArg codexConfigDir}
          configFile="$configDir/config.toml"
          baseline=${lib.escapeShellArg codexConfig}

          install -d -m 0700 "$configDir"

          if [[ -e "$configFile" && ! -f "$configFile" ]]; then
            echo "Refusing to replace non-file Codex config: $configFile" >&2
            exit 1
          fi

          tmpFile="$(mktemp "$configDir/config.toml.XXXXXX")"
          trap 'rm -f "$tmpFile"' EXIT

          if [[ -s "$configFile" ]]; then
            # Migration cleanup for stale keys from earlier declarative configs.
            ${pkgs.yq}/bin/tomlq -s -t '
              (.[0]
                | del(.apps)
                | del(.features.apps)
                | del(.features.codex_hooks)
                | del(.mcp_servers.codex_apps)) * .[1]
            ' "$configFile" "$baseline" >"$tmpFile"
          else
            cp "$baseline" "$tmpFile"
          fi

          chmod 0600 "$tmpFile"
          mv "$tmpFile" "$configFile"
          trap - EXIT
        '';

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
