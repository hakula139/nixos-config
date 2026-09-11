# ==============================================================================
# Agent Client Protocol (ACP)
# ==============================================================================

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.hakula.llm-assistants.acp;

  json = pkgs.formats.json { };

  # ----------------------------------------------------------------------------
  # Client package
  # ----------------------------------------------------------------------------
  # acpx excludes user settings by default, which would omit our Claude hooks,
  # permissions, and instructions.
  acpxBin = pkgs.symlinkJoin {
    name = "acpx-${pkgs.acpx.version}";
    paths = [ pkgs.acpx ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/acpx --set ACPX_CLAUDE_INCLUDE_USER_SETTINGS 1
    '';
  };

  # ----------------------------------------------------------------------------
  # Agent adapters
  # ----------------------------------------------------------------------------
  # Adapters export their resolved binary to child agents. Override inherited
  # values so nested delegation also uses our auth and proxy wrappers.
  mkAdapter =
    {
      pkg,
      bin,
      executableVar,
      executable,
    }:
    pkgs.symlinkJoin {
      name = "${bin}-${pkg.version}";
      paths = [ pkg ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/${bin} --set ${executableVar} ${lib.escapeShellArg executable}
      '';
    };

  claudeAdapter = mkAdapter {
    pkg = pkgs.claude-agent-acp;
    bin = "claude-agent-acp";
    executableVar = "CLAUDE_CODE_EXECUTABLE";
    executable = "${config.programs.claude-code.package}/bin/claude";
  };

  codexAdapter = mkAdapter {
    pkg = pkgs.codex-acp;
    bin = "codex-acp";
    executableVar = "CODEX_PATH";
    executable = "${config.programs.codex.package}/bin/codex";
  };

  # ----------------------------------------------------------------------------
  # Agent targets
  # ----------------------------------------------------------------------------
  # Session identity includes argv. Keep paths stable across rebuilds and
  # upstream basenames intact for adapter detection.
  profileBin = name: "${config.home.profileDirectory}/bin/${name}";

  managedAgents = {
    claude = {
      enable = config.hakula.claude-code.enable;
      option = "hakula.claude-code.enable";
      package = claudeAdapter;
      argv = [ (profileBin "claude-agent-acp") ];
    };

    codex = {
      enable = config.hakula.codex.enable;
      option = "hakula.codex.enable";
      package = codexAdapter;
      argv = [ (profileBin "codex-acp") ];
    };
  };

  enabledAgents = lib.filterAttrs (_: agent: agent.enable) managedAgents;

  # ----------------------------------------------------------------------------
  # Client configuration
  # ----------------------------------------------------------------------------
  # Missing entries fall back to acpx's unmanaged launch commands.
  mkUnavailable =
    name: agent:
    pkgs.writeShellScript "acpx-${name}-unavailable" ''
      echo "acpx: the ${name} agent needs ${agent.option} on this host" >&2
      exit 1
    '';

  agents = lib.mapAttrs (name: agent: {
    argv = if agent.enable then agent.argv else [ "${mkUnavailable name agent}" ];
  }) managedAgents;

  defaultAgent = if config.hakula.codex.enable then "codex" else "claude";

  configFile = json.generate "acpx-config.json" { inherit agents defaultAgent; };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.llm-assistants.acp.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.hakula.llm-assistants.enable && enabledAgents != { };
    description = "Whether to install the acpx client for the enabled Claude Code and Codex assistants";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = enabledAgents != { };
        message = "hakula.llm-assistants.acp requires Claude Code or Codex to be enabled";
      }
    ];

    home.packages = [ acpxBin ] ++ lib.mapAttrsToList (_: agent: agent.package) enabledAgents;

    home.file.".acpx/config.json".source = configFile;
  };
}
