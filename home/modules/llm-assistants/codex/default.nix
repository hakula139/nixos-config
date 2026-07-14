# ==============================================================================
# Codex Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  corpDomain,
  llmAssistantLib,
  proxyLib,
  repo,
  secretPath,
  ...
}:

let
  cfg = config.hakula.codex;

  agentRoleOptions = import ../shared/agent-roles/options.nix { inherit lib; };
  inherit (llmAssistantLib) mcpOptions;
  instructions = import ../shared/instructions;

  codexMcpServers = mcpOptions.commonServerNames ++ [ "context7" ];
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

    mcp = mcpOptions.mkMcpOptions { names = codexMcpServers; };

    proxy = proxyLib.mkProxyOptions "Codex";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      toml = pkgs.formats.toml { };

      # ------------------------------------------------------------------------
      # Module imports
      # ------------------------------------------------------------------------
      notify = import ../shared/notify.nix { inherit pkgs lib; };
      hooks = import ./hooks.nix { inherit pkgs lib repo; };

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

      skills = import ./skills { inherit pkgs lib inputs; };

      agents = import ./agents.nix {
        inherit pkgs lib;
        inherit (cfg.agents) enabledAgents;
      };

      # ------------------------------------------------------------------------
      # Package wrapper
      # ------------------------------------------------------------------------
      codexPkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;

      # Keep codex version in the derivation name so Home Manager detects
      # this as a modern codex for config directory layout.
      codexBin = proxyLib.wrapWithProxy {
        inherit pkgs;
        pkg = codexPkg;
        proxyCfg = cfg.proxy;
        name = "codex-${codexPkg.version}";
        bin = "codex";
      };

      codexSettings = import ./settings.nix {
        inherit
          agents
          hooks
          mcp
          notify
          skills
          ;
      };

      codexConfig = toml.generate "codex-config" codexSettings;
      codexConfigDir =
        if config.home.preferXdgDirectories then
          "${config.xdg.configHome}/codex"
        else
          "${config.home.homeDirectory}/.codex";

      # Separate from default.rules, which Codex rewrites on TUI allowlisting.
      codexRulesTarget =
        if config.home.preferXdgDirectories then
          "${lib.removePrefix "${config.home.homeDirectory}/" config.xdg.configHome}/codex/rules/nixos-config.rules"
        else
          ".codex/rules/nixos-config.rules";
    in
    lib.mkMerge [
      {
        # ----------------------------------------------------------------------
        # Program configuration
        # ----------------------------------------------------------------------
        programs.codex = {
          enable = true;
          package = codexBin;
          context = instructions.codex;
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

        home.file = skills.homeFile // {
          codexRules = {
            target = codexRulesTarget;
            text = llmAssistantLib.permissions.codexRules + "\n";
          };
        };
      }
    ]
  );
}
