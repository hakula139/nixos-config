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
      toml = pkgs.formats.toml { };

      # ------------------------------------------------------------------------
      # Module imports
      # ------------------------------------------------------------------------
      hooks = import ./hooks.nix { inherit pkgs lib; };
      notify = import ../shared/notify.nix { inherit pkgs lib; };
      skills = import ./skills { inherit pkgs lib inputs; };

      agents = import ./agents.nix {
        inherit lib pkgs;
        inherit (cfg.agents) enabledAgents;
      };

      mcp = import ./mcp.nix {
        inherit
          config
          pkgs
          lib
          secrets
          isNixOS
          ;
        enabledServers = lib.subtractLists cfg.mcp.disabledServers cfg.mcp.enabledServers;
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

      codexSettings = import ./settings.nix {
        inherit
          agents
          hooks
          mcp
          skills
          notify
          ;
      };

      codexConfig = toml.generate "codex-config" codexSettings;
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
            ${pkgs.yq}/bin/tomlq -s -t '.[0] * .[1]' "$configFile" "$baseline" >"$tmpFile"
          else
            cp "$baseline" "$tmpFile"
          fi

          chmod 0600 "$tmpFile"
          mv "$tmpFile" "$configFile"
          trap - EXIT
        '';

        home.file = skills.homeFile;
      }
    ]
  );
}
