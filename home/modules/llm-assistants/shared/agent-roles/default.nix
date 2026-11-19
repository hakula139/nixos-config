# ==================================================================================================
# Shared Agent Roles
# ==================================================================================================

{
  promptFragments,
}:

let
  inherit (promptFragments) readPrompt roleSections;

  composePrompt = name: ''
    ${readPrompt ./prompts/${name}.md}
    ${roleSections.memory}
    ${roleSections.coordination}
    ### Role-Specific Coordination

    ${readPrompt ./coordination/${name}.md}
    ${roleSections.status}
  '';

  roles = {
    architect = {
      description = ''
        Architecture review, design critique, and design proposals. Use when you need a design for a
        new feature or significant change, feedback on an approach, or analysis of code structure,
        design patterns, and dependency relationships.
      '';

      workload = "flagship";

      claude = {
        color = "cyan";
        memory = "local";
        permissionMode = "plan";
      };

      codex = {
        sandboxMode = "read-only";
        nicknameCandidates = [
          "architect"
          "arch"
        ];
      };

      omp = {
        tools = [
          "ast_grep"
          "glob"
          "grep"
          "read"
          "web_search"
        ];
      };
    };

    debugger = {
      description = ''
        Hypothesis-driven debugging and root cause analysis. Use when you need to investigate a bug,
        unexpected behavior, or failure, especially when the cause is unclear.
      '';

      workload = "flagship";

      claude = {
        color = "red";
        memory = "local";
      };

      codex = {
        nicknameCandidates = [
          "debugger"
          "debug"
        ];
      };

      omp = {
        spawns = "*";
      };
    };

    doc-writer = {
      description = ''
        Documentation and prose authoring, restructuring, translation, and polishing across English,
        Chinese, and all languages. Use when drafting, revising, translating, or polishing
        documentation, guides, READMEs, or prose under the Writing and Documentation guides.
      '';

      workload = "prose";

      claude = {
        color = "purple";
        memory = "local";
        skills = [ "git-workflow" ];
      };

      codex = {
        nicknameCandidates = [
          "doc-writer"
          "writer"
        ];
      };

      omp = {
        spawns = "*";
      };
    };

    implementer = {
      description = ''
        Code writing, feature implementation, and refactoring. Use when you need to delegate a
        self-contained coding task.
      '';

      workload = "standard";

      claude = {
        color = "yellow";
        memory = "local";
        skills = [ "git-workflow" ];
      };

      codex = {
        nicknameCandidates = [
          "implementer"
          "builder"
        ];
      };

      omp = {
        spawns = "*";
      };
    };

    operator = {
      description = ''
        Approved publication and operations. Use after the user approves a merge, or for multi-step
        Git, forge, and host operations: merging approved PRs / MRs, waiting for CI, cleaning up
        branches and worktrees, syncing forges, and switching or deploying hosts.
      '';

      workload = "mini";

      claude = {
        color = "orange";
        memory = "local";
        skills = [ "git-workflow" ];
      };

      codex = {
        nicknameCandidates = [
          "operator"
          "ops"
        ];
      };
    };

    researcher = {
      description = ''
        Fast codebase exploration and documentation lookup. Use when you need to gather context from
        multiple files, search for patterns, or look up external documentation.
      '';

      workload = "mini";

      claude = {
        color = "blue";
        memory = "local";
        background = true;
        permissionMode = "plan";
      };

      codex = {
        sandboxMode = "read-only";
        nicknameCandidates = [
          "researcher"
          "explorer"
        ];
      };

      omp = {
        tools = [
          "ast_grep"
          "glob"
          "grep"
          "read"
          "web_search"
        ];
      };
    };

    reviewer = {
      description = ''
        Convention, simplicity, and correctness review across every dimension. Use after
        implementation or before a merge to review recent changes, or to audit existing code.
      '';

      workload = "flagship";

      claude = {
        color = "green";
        memory = "local";
        permissionMode = "plan";
      };

      codex = {
        sandboxMode = "read-only";
        nicknameCandidates = [
          "reviewer"
          "audit"
        ];
      };

      omp = {
        tools = [
          "ast_grep"
          "glob"
          "grep"
          "read"
          "web_search"
        ];
        spawns = "reviewer";
      };
    };

    tester = {
      description = ''
        Test writing, test execution, and failure analysis. Use when you need tests written for new
        code, want to run existing tests, or need help diagnosing test failures.
      '';

      workload = "flagship";

      claude = {
        color = "magenta";
        memory = "local";
      };

      codex = {
        nicknameCandidates = [
          "tester"
          "qa"
        ];
      };

      omp = {
        spawns = "*";
      };
    };

    usability-reviewer = {
      description = ''
        Usability and clarity review from a first-time user's perspective. Use after implementation to
        evaluate user-facing surfaces such as APIs, docs, CLI help text, error messages, and UI copy.
      '';

      workload = "flagship";

      claude = {
        color = "gray";
        memory = "local";
        permissionMode = "plan";
      };

      codex = {
        sandboxMode = "read-only";
        nicknameCandidates = [
          "usability"
          "ux-review"
        ];
      };

      omp = {
        tools = [
          "ast_grep"
          "glob"
          "grep"
          "read"
          "web_search"
        ];
      };
    };
  };
in
builtins.mapAttrs (name: role: role // { prompt = composePrompt name; }) roles
