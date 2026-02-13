{
  lib,
  enabledAgents,
  codexEnabled ? false,
}:

# ==============================================================================
# Claude Code Custom Agents
# ==============================================================================

let
  allAgents = {
    architect = builtins.readFile ./architect.md;
    debugger = builtins.readFile ./debugger.md;
    implementer = builtins.readFile ./implementer.md;
    researcher = builtins.readFile ./researcher.md;
    reviewer = builtins.readFile ./reviewer.md;
    tester = builtins.readFile ./tester.md;
    usability-reviewer = builtins.readFile ./usability-reviewer.md;
  }
  // lib.optionalAttrs codexEnabled {
    codex-worker = builtins.readFile ./codex-worker.md;
  };
in
lib.filterAttrs (name: _: lib.elem name enabledAgents) allAgents
