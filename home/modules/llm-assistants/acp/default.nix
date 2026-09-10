# ==============================================================================
# Agent Client Protocol (ACP)
# ==============================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  repoLib,
  ...
}:

let
  cfg = config.hakula.llm-assistants.acp;
  proxyCfg = config.hakula.llm-assistants.proxy;

  json = pkgs.formats.json { };

  acpPackages = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  # Session identity includes argv. Keep paths stable across rebuilds and
  # upstream basenames intact for adapter detection.
  profileBin = name: "${config.home.profileDirectory}/bin/${name}";

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
    pkg = acpPackages.claude-agent-acp;
    bin = "claude-agent-acp";
    executableVar = "CLAUDE_CODE_EXECUTABLE";
    executable = "${config.programs.claude-code.package}/bin/claude";
  };

  codexAdapter = mkAdapter {
    pkg = acpPackages.codex-acp;
    bin = "codex-acp";
    executableVar = "CODEX_PATH";
    executable = "${config.programs.codex.package}/bin/codex";
  };

  cursorAgent = repoLib.proxy.wrapWithProxy {
    inherit pkgs proxyCfg;
    pkg = acpPackages.cursor-agent;
    name = "cursor-agent-${acpPackages.cursor-agent.version}";
    bin = "cursor-agent";
  };

  managedAgents = {
    claude = {
      enable = config.hakula.claude-code.enable;
      option = "hakula.claude-code.enable";
      packages = [ claudeAdapter ];
      argv = [ (profileBin "claude-agent-acp") ];
    };

    codex = {
      enable = config.hakula.codex.enable;
      option = "hakula.codex.enable";
      packages = [ codexAdapter ];
      argv = [ (profileBin "codex-acp") ];
    };

    cursor = {
      enable = cfg.cursor.enable;
      option = "hakula.llm-assistants.acp.cursor.enable";
      packages = [ cursorAgent ];
      argv = [
        (profileBin "cursor-agent")
        "acp"
      ];
    };

    opencode = {
      enable = config.hakula.opencode.enable;
      option = "hakula.opencode.enable";
      packages = [ ];
      argv = [
        (profileBin "opencode")
        "acp"
      ];
    };
  };

  enabledAgents = lib.filterAttrs (_: agent: agent.enable) managedAgents;

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

  defaultAgent = lib.findFirst (name: managedAgents.${name}.enable) "codex" [
    "codex"
    "claude"
    "opencode"
    "cursor"
  ];

  configFile = json.generate "acpx-config.json" { inherit agents defaultAgent; };

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
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.llm-assistants.acp = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.hakula.llm-assistants.enable;
      description = "Whether to install the acpx ACP client and register the managed assistants";
    };

    cursor.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.hakula.cursor.enable;
      description = ''
        Whether to install the Cursor CLI as an ACP target. It uses Cursor login
        or API-token authentication independently of the editor configuration.
      '';
    };
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = enabledAgents != { };
        message = "hakula.llm-assistants.acp needs at least one assistant enabled to delegate to";
      }
    ];

    home.packages = [ acpxBin ] ++ lib.concatMap (agent: agent.packages) (lib.attrValues enabledAgents);

    home.file.".acpx/config.json".source = configFile;
  };
}
