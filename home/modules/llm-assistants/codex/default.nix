# ==============================================================================
# Codex Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  corpHosts,
  hostType,
  llmAssistantLib,
  proxyLib,
  repo,
  secretPath,
  enableDevToolchains ? false,
  ...
}:

let
  cfg = config.hakula.codex;

  agentRoleOptions = import ../shared/agent-roles/options.nix { inherit lib; };
  inherit (llmAssistantLib) mcpOptions;
  instructions = import ../shared/instructions;
  codexPkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;

  codexMcpServers = mcpOptions.commonServerNames ++ [ "context7" ];
  codexConfigDir =
    if config.home.preferXdgDirectories then
      "${config.xdg.configHome}/codex"
    else
      "${config.home.homeDirectory}/.codex";
  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      codexPkg
      corpHosts
      hostType
      secretPath
      ;
    configDir = codexConfigDir;
  };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.codex = {
    enable = lib.mkEnableOption "OpenAI Codex CLI";

    auth = profiles.options;

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
      notify = import ../shared/notify { inherit pkgs lib; };
      hooks = import ./hooks.nix {
        inherit
          pkgs
          lib
          repo
          enableDevToolchains
          ;
      };

      mcp = import ./mcp.nix {
        inherit
          config
          pkgs
          lib
          llmAssistantLib
          corpHosts
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
      proxyScript = pkgs.writeShellScript "codex-proxy-env" (proxyLib.mkProxyScript cfg.proxy);

      # Home Manager uses the version in the name to select the config layout.
      codexBin = pkgs.symlinkJoin {
        name = "codex-${codexPkg.version}";
        paths = [ codexPkg ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/codex \
            --run ${lib.escapeShellArg "source ${profiles.loader}"} \
            ${lib.optionalString cfg.proxy.enable "--run ${lib.escapeShellArg "source ${proxyScript}"}"}
        '';
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

      # Separate from default.rules, which Codex rewrites on TUI allowlisting.
      codexRulesTarget =
        if config.home.preferXdgDirectories then
          "${lib.removePrefix "${config.home.homeDirectory}/" config.xdg.configHome}/codex/rules/nixos-config.rules"
        else
          ".codex/rules/nixos-config.rules";
    in
    lib.mkMerge [
      profiles.config
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
            ${pkgs.yq}/bin/tomlq -s -t '
              . as [$current, $baseline]
              | $current * $baseline
              | .mcp_servers = $baseline.mcp_servers
              | .hooks = (
                  $baseline.hooks
                  + (if $current.hooks.state? then { state: $current.hooks.state } else { } end)
                )
            ' "$configFile" "$baseline" >"$tmpFile"
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
