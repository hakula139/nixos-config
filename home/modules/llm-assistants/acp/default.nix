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

  # acpx keys a saved session on the exact agent command string, so argv names a
  # profile path: a store path would orphan every persistent session as soon as
  # the adapter or the agent behind it is rebuilt. acpx also identifies an
  # adapter by basename, so each launcher keeps its upstream program name.
  profileBin = name: "${config.home.profileDirectory}/bin/${name}";

  # Both adapters take their agent binary from an environment variable, fall back
  # to an unwrapped bundled build, and export the resolved value into the agent
  # they start. An agent delegating onwards hands acpx those unwrapped paths, so
  # the launcher overwrites rather than fills in: only the configured binaries
  # carry the auth profile, proxy env and --mcp-config.
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

  # The Cursor CLI serves ACP itself, and the editor module provisions no binary,
  # so this target brings its own. Nothing else wraps it, hence the proxy here.
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
  enabledAgentNames = lib.attrNames enabledAgents;

  # A disabled assistant keeps its entry. Dropping the name instead would uncover
  # acpx's built-in command for it, which fetches and runs an unmanaged agent.
  mkUnavailable =
    name: agent:
    pkgs.writeShellScript "acpx-${name}-unavailable" ''
      echo "acpx: the ${name} agent needs ${agent.option} on this host" >&2
      exit 1
    '';

  agents = lib.mapAttrs (name: agent: {
    argv = if agent.enable then agent.argv else [ "${mkUnavailable name agent}" ];
  }) managedAgents;

  # Upstream aims a target-less prompt at `codex`, which reaches the stub on a
  # host without it.
  defaultAgent = lib.findFirst (name: lib.elem name enabledAgentNames) "codex" [
    "codex"
    "claude"
    "opencode"
    "cursor"
  ];

  configFile = json.generate "acpx-config.json" { inherit agents defaultAgent; };

  # acpx confines a Claude ACP session to project and local settings unless this
  # says otherwise, and this repo keeps Claude's settings, hooks, permissions and
  # instructions user-scoped.
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
        Whether to register Cursor as an ACP target. Unlike the other three, this
        installs a CLI the editor configuration does not provide, and it
        authenticates through Cursor's own login rather than a managed secret.
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

    # acpx derives its config and session state root from the home directory.
    home.file.".acpx/config.json".source = configFile;
  };
}
