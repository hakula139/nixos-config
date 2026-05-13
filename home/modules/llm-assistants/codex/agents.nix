# ==============================================================================
# Codex Custom Agents
# ==============================================================================

{
  pkgs,
  lib,
  enabledAgents,
  ...
}:

let
  toml = pkgs.formats.toml { };

  sharedAgents = import ../shared/agent-roles;

  mkAgentConfig =
    name: agent:
    let
      configFile = toml.generate "codex-agent-${name}" {
        developer_instructions = agent.prompt;
        model_reasoning_effort = "high";
        personality = "pragmatic";
      };
    in
    {
      inherit (agent) description;
      config_file = toString configFile;
      nickname_candidates = agent.codex.nicknameCandidates or [ ];
    };
in
{
  settings = {
    max_threads = 8;
    max_depth = 3;
    job_max_runtime_seconds = 1800;
  }
  // lib.mapAttrs mkAgentConfig (lib.filterAttrs (name: _: lib.elem name enabledAgents) sharedAgents);
}
