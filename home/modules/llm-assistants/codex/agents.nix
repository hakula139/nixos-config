# ==============================================================================
# Codex Custom Agents
# ==============================================================================

{
  pkgs,
  lib,
  sharedAgents,
  enabledAgents,
  workloads,
}:

let
  toml = pkgs.formats.toml { };

  mkAgentConfig =
    name: agent:
    let
      configFile = toml.generate "codex-agent-${name}" (
        {
          developer_instructions = agent.prompt;
          model = workloads.${agent.workload}.modelId;
          model_reasoning_effort = workloads.${agent.workload}.effort;
          personality = "pragmatic";
        }
        // lib.optionalAttrs (agent.codex ? sandboxMode) {
          sandbox_mode = agent.codex.sandboxMode;
        }
      );
    in
    {
      inherit (agent) description;
      config_file = toString configFile;
      nickname_candidates = agent.codex.nicknameCandidates;
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
