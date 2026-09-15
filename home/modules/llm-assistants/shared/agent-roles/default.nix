# ==============================================================================
# Shared Agent Roles
# ==============================================================================

let
  fragments = {
    "@preamble@" = ./prompts/preamble.md;
    "@memory@" = ./prompts/memory.md;
    "@coordination@" = ./prompts/coordination.md;
  };

  readPrompt =
    file:
    builtins.replaceStrings (builtins.attrNames fragments) (map builtins.readFile (
      builtins.attrValues fragments
    )) (builtins.readFile file);
in
{
  architect = {
    description = ''
      Architecture review and design critique. Use when you need analysis of code structure, design
      patterns, dependency relationships, or feedback on an approach before implementation.
    '';
    prompt = readPrompt ./prompts/architect.md;
    claude = {
      color = "cyan";
      effort = "xhigh";
      memory = "local";
      permissionMode = "plan";
    };
    codex = {
      reasoningEffort = "high";
      sandboxMode = "read-only";
      nicknameCandidates = [
        "architect"
        "arch"
      ];
    };
    omp = {
      model = "@plan";
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
    claude = {
      color = "red";
      effort = "xhigh";
      memory = "local";
    };
    codex = {
      reasoningEffort = "high";
      nicknameCandidates = [
        "debugger"
        "debug"
      ];
    };
    omp = {
      model = "@slow";
      spawns = "*";
    };
    opencode = { };
  };

  implementer = {
    description = ''
      Code writing, feature implementation, and refactoring. Use when you need to delegate a
      self-contained coding task, including writing new features, applying changes, or refactoring
      code.
    '';
    prompt = readPrompt ./prompts/implementer.md;
    claude = {
      color = "yellow";
      effort = "high";
      memory = "local";
    };
    codex = {
      reasoningEffort = "high";
      nicknameCandidates = [
        "implementer"
        "builder"
      ];
    };
    omp = {
      model = "@default";
      spawns = "*";
    };
    opencode = { };
  };

  researcher = {
    description = ''
      Fast codebase exploration and documentation lookup. Use when you need to gather context from
      multiple files, search for patterns, or look up external documentation.
    '';
    prompt = readPrompt ./prompts/researcher.md;
    modelTier = "mini";
    effort = {
      claude = "low";
      gpt = "medium";
    };
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
      model = "@smol";
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
    claude = {
      color = "green";
      effort = "xhigh";
      memory = "local";
      permissionMode = "plan";
    };
    codex = {
      reasoningEffort = "high";
      sandboxMode = "read-only";
      nicknameCandidates = [
        "reviewer"
        "audit"
      ];
    };
    omp = {
      model = "@slow";
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
    claude = {
      color = "magenta";
      model = "sonnet";
      effort = "medium";
      memory = "local";
    };
    codex = {
      reasoningEffort = "medium";
      nicknameCandidates = [
        "tester"
        "qa"
      ];
    };
    omp = {
      model = "@default";
      spawns = "*";
    };
    opencode = { };
  };

  usability-reviewer = {
    description = ''
      Usability and clarity review from a non-expert perspective. Use after implementation to
      evaluate user-facing surfaces such as APIs, docs, CLI help text, error messages, and UI copy
      for intuitiveness and clarity.
    '';
    prompt = readPrompt ./prompts/usability-reviewer.md;
    claude = {
      color = "gray";
      effort = "medium";
      memory = "local";
      permissionMode = "plan";
    };
    codex = {
      reasoningEffort = "medium";
      sandboxMode = "read-only";
      nicknameCandidates = [
        "usability"
        "ux-review"
      ];
    };
    omp = {
      model = "@plan";
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
