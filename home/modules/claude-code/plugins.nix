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
    "code-review@claude-code-plugins" = true;
    "commit-commands@claude-code-plugins" = true;
    "explanatory-output-style@claude-code-plugins" = true;
    "feature-dev@claude-code-plugins" = true;
    "frontend-design@claude-code-plugins" = true;
    "hookify@claude-plugins-official" = true; # bug fixed version
    "learning-output-style@claude-code-plugins" = true;
    "pr-review-toolkit@claude-code-plugins" = true;
    "ralph-wiggum@claude-code-plugins" = true;
    "security-guidance@claude-code-plugins" = true;

    # Official LSP plugins
    "pyright-lsp@claude-plugins-official" = true;
    "typescript-lsp@claude-plugins-official" = true;

    # Third-party plugins
    "agent-browser@agent-browser" = true;
    "claude-code-wakatime@wakatime" = true;
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
    claude-code-plugins = {
      source = {
        source = "github";
        repo = "anthropics/claude-code";
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
    wakatime = {
      source = {
        source = "github";
        repo = "wakatime/claude-code-wakatime";
      };
    };
  };
}
