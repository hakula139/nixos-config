{
  lib,
  enableDevToolchains ? false,
  ...
}:

# ==============================================================================
# Claude Code Plugins
# ==============================================================================

{
  # ----------------------------------------------------------------------------
  # Enabled plugins
  # ----------------------------------------------------------------------------
  enabledPlugins = {
    # Official skills
    "document-skills@anthropic-agent-skills" = true;
    "example-skills@anthropic-agent-skills" = true;

    # Official plugins
    "code-review@claude-plugins-official" = true;
    "commit-commands@claude-plugins-official" = true;
    "explanatory-output-style@claude-plugins-official" = true;
    "feature-dev@claude-plugins-official" = true;
    "frontend-design@claude-plugins-official" = true;
    "hookify@claude-plugins-official" = true;
    "learning-output-style@claude-plugins-official" = true;
    "pr-review-toolkit@claude-plugins-official" = true;
    "ralph-loop@claude-plugins-official" = true;
    "security-guidance@claude-plugins-official" = true;

    # Official LSP plugins
    "pyright-lsp@claude-plugins-official" = true;
    "typescript-lsp@claude-plugins-official" = true;

    # Third-party plugins
    "agent-browser@agent-browser" = true;
    "claude-code-wakatime@wakatime" = true;
    "context7-plugin@context7-marketplace" = true;
  }
  # Dev toolchain plugins (require C/C++, Go, Rust toolchains)
  // lib.optionalAttrs enableDevToolchains {
    # Official LSP plugins
    "clangd-lsp@claude-plugins-official" = true;
    "gopls-lsp@claude-plugins-official" = true;
    "rust-analyzer-lsp@claude-plugins-official" = true;
  };

  # ----------------------------------------------------------------------------
  # Custom marketplaces
  # ----------------------------------------------------------------------------
  extraKnownMarketplaces = {
    anthropic-agent-skills = {
      source = {
        source = "github";
        repo = "anthropics/skills";
      };
    };
    claude-plugins-official = {
      source = {
        source = "github";
        repo = "anthropics/claude-plugins-official";
      };
    };
    agent-browser = {
      source = {
        source = "github";
        repo = "vercel-labs/agent-browser";
      };
    };
    context7-marketplace = {
      source = {
        source = "github";
        repo = "upstash/context7";
      };
    };
    wakatime = {
      source = {
        source = "github";
        repo = "wakatime/claude-code-wakatime";
      };
    };
  };
}
