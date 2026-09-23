# ==============================================================================
# Shared Agent Roles
# ==============================================================================

{
  readPrompt,
}:

{
  architect = {
    description = ''
      Architecture review and design critique. Use when you need analysis of code structure, design
      patterns, dependency relationships, or feedback on an approach before implementation.
    '';
    prompt = readPrompt ./prompts/architect.md;
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
    opencode = {
      permission = {
        bash = "deny";
        edit = "deny";
      };
    };
  };

  debugger = {
    description = ''
      Hypothesis-driven debugging and root cause analysis. Use when you need to investigate a bug,
      unexpected behavior, or failure, especially when the cause is unclear.
    '';
    prompt = readPrompt ./prompts/debugger.md;
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

  implementer = {
    description = ''
      Code writing, feature implementation, and refactoring. Use when you need to delegate a
      self-contained coding task, including writing new features, applying changes, or refactoring
      code.
    '';
    prompt = readPrompt ./prompts/implementer.md;
    workload = "flagship";

    claude = {
      color = "yellow";
      memory = "local";
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

  researcher = {
    description = ''
      Fast codebase exploration and documentation lookup. Use when you need to gather context from
      multiple files, search for patterns, or look up external documentation.
    '';
    prompt = readPrompt ./prompts/researcher.md;
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
    opencode = {
      permission = {
        bash = "deny";
        edit = "deny";
      };
    };
  };

  reviewer = {
    description = ''
      Code quality review, security analysis, and bug detection. Use after implementation to get a
      focused review of recent changes, or to audit existing code for issues.
    '';
    prompt = readPrompt ./prompts/reviewer.md;
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
    };
    opencode = {
      permission = {
        bash = "deny";
        edit = "deny";
      };
    };
  };

  tester = {
    description = ''
      Test writing and execution, failure analysis. Use when you need tests written for new code,
      want to run existing tests, or need help diagnosing test failures.
    '';
    prompt = readPrompt ./prompts/tester.md;
    workload = "standard";

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
      Usability and clarity review from a non-expert perspective. Use after implementation to
      evaluate user-facing surfaces such as APIs, docs, CLI help text, error messages, and UI copy
      for intuitiveness and clarity.
    '';
    prompt = readPrompt ./prompts/usability-reviewer.md;
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
    opencode = {
      permission = {
        bash = "deny";
        edit = "deny";
      };
    };
  };
}
