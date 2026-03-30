# ==============================================================================
# Shared Agent Roles
# ==============================================================================

let
  preamble = builtins.readFile ./prompts/preamble.md;
  readPrompt = file: preamble + "\n" + builtins.readFile file;
in
{
  architect = {
    description = "Architecture review and design critique. Use when you need analysis of code structure, design patterns, dependency relationships, or feedback on an approach before implementation.";
    prompt = readPrompt ./prompts/architect.md;
    claude = {
      color = "cyan";
    };
    codex = {
      nicknameCandidates = [
        "architect"
        "arch"
      ];
    };
    opencode = {
      tools = {
        write = false;
        edit = false;
        bash = false;
      };
    };
  };

  debugger = {
    description = "Hypothesis-driven debugging and root cause analysis. Use when you need to investigate a bug, unexpected behavior, or failure, especially when the cause is unclear.";
    prompt = readPrompt ./prompts/debugger.md;
    claude = {
      color = "red";
    };
    codex = {
      nicknameCandidates = [
        "debugger"
        "debug"
      ];
    };
    opencode = { };
  };

  implementer = {
    description = "Code writing, feature implementation, and refactoring. Use when you need to delegate a self-contained coding task, including writing new features, applying changes, or refactoring code.";
    prompt = readPrompt ./prompts/implementer.md;
    claude = {
      color = "yellow";
    };
    codex = {
      nicknameCandidates = [
        "implementer"
        "builder"
      ];
    };
    opencode = { };
  };

  researcher = {
    description = "Fast codebase exploration and documentation lookup. Use when you need to gather context from multiple files, search for patterns, or look up external documentation.";
    prompt = readPrompt ./prompts/researcher.md;
    claude = {
      color = "blue";
      model = "haiku";
    };
    codex = {
      nicknameCandidates = [
        "researcher"
        "explorer"
      ];
    };
    opencode = {
      tools = {
        write = false;
        edit = false;
        bash = false;
      };
    };
  };

  reviewer = {
    description = "Code quality review, security analysis, and bug detection. Use after implementation to get a focused review of recent changes, or to audit existing code for issues.";
    prompt = readPrompt ./prompts/reviewer.md;
    claude = {
      color = "green";
    };
    codex = {
      nicknameCandidates = [
        "reviewer"
        "audit"
      ];
    };
    opencode = {
      tools = {
        write = false;
        edit = false;
        bash = false;
      };
    };
  };

  tester = {
    description = "Test writing and execution, failure analysis. Use when you need tests written for new code, want to run existing tests, or need help diagnosing test failures.";
    prompt = readPrompt ./prompts/tester.md;
    claude = {
      color = "magenta";
      model = "sonnet";
    };
    codex = {
      nicknameCandidates = [
        "tester"
        "qa"
      ];
    };
    opencode = { };
  };

  usability-reviewer = {
    description = "Usability and clarity review from a non-expert perspective. Use after implementation to evaluate user-facing surfaces such as APIs, docs, CLI help text, error messages, and UI copy for intuitiveness and clarity.";
    prompt = readPrompt ./prompts/usability-reviewer.md;
    claude = {
      color = "gray";
    };
    codex = {
      nicknameCandidates = [
        "usability"
        "ux-review"
      ];
    };
    opencode = {
      tools = {
        write = false;
        edit = false;
        bash = false;
      };
    };
  };
}
