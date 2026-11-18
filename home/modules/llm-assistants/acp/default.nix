# ==================================================================================================
# Agent Client Protocol (ACP)
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  ...
}:

let
  json = pkgs.formats.json { };

  # ------------------------------------------------------------------------------------------------
  # Client package
  # ------------------------------------------------------------------------------------------------
  # acpx skips user settings by default, dropping our Claude hooks, permissions, and instructions.
  acpxBin = repoLib.wrapPackage {
    inherit pkgs;
    pkg = pkgs.acpx;
    name = "acpx-${pkgs.acpx.version}";
    bin = "acpx";
    envVars.ACPX_CLAUDE_INCLUDE_USER_SETTINGS = "1";
  };

  # ------------------------------------------------------------------------------------------------
  # Agent adapters
  # ------------------------------------------------------------------------------------------------
  # Adapters export their resolved binary to child agents. Override inherited values so nested
  # delegation also uses our auth and proxy wrappers.
  mkAdapter =
    {
      pkg,
      bin,
      executableVar,
      executable,
    }:
    repoLib.wrapPackage {
      inherit pkgs pkg bin;
      name = "${bin}-${pkg.version}";
      envVars.${executableVar} = executable;
    };

  claudeAdapter = mkAdapter {
    pkg = pkgs.claude-agent-acp;
    bin = "claude-agent-acp";
    executableVar = "CLAUDE_CODE_EXECUTABLE";
    executable = lib.getExe' config.programs.claude-code.package "claude";
  };

  codexAdapter = mkAdapter {
    pkg = pkgs.codex-acp;
    bin = "codex-acp";
    executableVar = "CODEX_PATH";
    executable = lib.getExe' config.programs.codex.package "codex";
  };

  # ------------------------------------------------------------------------------------------------
  # Client configuration
  # ------------------------------------------------------------------------------------------------
  # Session identity includes argv. Keep paths stable across rebuilds and upstream basenames intact
  # for adapter detection.
  profileBin = name: "${config.home.profileDirectory}/bin/${name}";

  agents = {
    claude.argv = [ (profileBin "claude-agent-acp") ];
    codex.argv = [ (profileBin "codex-acp") ];
  };

  defaultAgent = "codex";

  configFile = json.generate "acpx-config.json" {
    inherit agents defaultAgent;
    # Seconds each prompt waits for a response before acpx exits with code 3
    timeout = 600;
  };
in
lib.mkIf config.hakula.llm-assistants.enable {
  home.packages = [
    acpxBin
    claudeAdapter
    codexAdapter
  ];

  home.file.".acpx/config.json".source = configFile;
}
