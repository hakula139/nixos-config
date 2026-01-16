# ==============================================================================
# Claude Code Plugins
# ==============================================================================

{
  # ----------------------------------------------------------------------------
  # Enabled plugins
  # ----------------------------------------------------------------------------
  enabledPlugins = {
    # Anthropic plugins
    "code-review@claude-code-plugins" = true;
    "commit-commands@claude-code-plugins" = true;
    "explanatory-output-style@claude-code-plugins" = true;
    "feature-dev@claude-code-plugins" = true;
    "frontend-design@claude-code-plugins" = true;
    "hookify@claude-code-plugins" = true;
    "learning-output-style@claude-code-plugins" = true;
    "pr-review-toolkit@claude-code-plugins" = true;
    "ralph-wiggum@claude-code-plugins" = true;
    "security-guidance@claude-code-plugins" = true;

    # Third-party plugins
    "claude-code-wakatime@wakatime" = true;
  };

  # ----------------------------------------------------------------------------
  # Custom marketplaces
  # ----------------------------------------------------------------------------
  extraKnownMarketplaces = {
    claude-code-plugins = {
      source = {
        source = "github";
        repo = "anthropics/claude-code";
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
