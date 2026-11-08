# ==================================================================================================
# Claude Code Settings
# ==================================================================================================

{
  hooks,
  permissionSettings,
  plugins,
  profileSettings,
  shared,
}:

{
  hooks = hooks.events;
  inherit (plugins) enabledPlugins extraKnownMarketplaces;
}
// permissionSettings
// profileSettings
// {
  # ------------------------------------------------------------------------------------------------
  # Project
  # ------------------------------------------------------------------------------------------------
  plansDirectory = "./${shared.preferences.plansDir}";

  includeGitInstructions = false;
  attribution = {
    commit = "";
    pr = "";
  };

  # ------------------------------------------------------------------------------------------------
  # Skills
  # ------------------------------------------------------------------------------------------------
  skillOverrides = {
    code-review = "off";
    security-review = "off";
    simplify = "off";
  };

  # ------------------------------------------------------------------------------------------------
  # Interface
  # ------------------------------------------------------------------------------------------------
  theme = "dark";
  tui = "fullscreen";
  statusLine = {
    type = "command";
    command = "${shared.claudeConfigDir}/statusline-command";
  };

  showThinkingSummaries = true;

  wheelScrollAccelerationEnabled = false;

  # ------------------------------------------------------------------------------------------------
  # Interaction
  # ------------------------------------------------------------------------------------------------
  askUserQuestionTimeout =
    {
      "60" = "60s";
      "300" = "5m";
      "600" = "10m";
    }
    .${toString shared.preferences.askTimeout};

  # ------------------------------------------------------------------------------------------------
  # Sessions
  # ------------------------------------------------------------------------------------------------
  crossSessionInbound = "accept";

  awaySummaryEnabled = false;

  # ------------------------------------------------------------------------------------------------
  # Environment
  # ------------------------------------------------------------------------------------------------
  env = {
    API_FORCE_IDLE_TIMEOUT = "0";
    API_TIMEOUT_MS = "1800000";
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
    CLAUDE_CODE_ENABLE_AUTO_MODE = "1";
    CLAUDE_CODE_ENABLE_TODO_TOOLS = "1";
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    # Also stops the subagent progress summaries, which fork the subagent's context.
    CLAUDE_CODE_FORK_SUBAGENT = "0";
    CLAUDE_CODE_SCROLL_SPEED = "1";
    CLAUDE_CODE_STOP_HOOK_BLOCK_CAP = "3";
    DISABLE_INSTALLATION_CHECKS = "1";
    ENABLE_CLAUDEAI_MCP_SERVERS = "0";
    ENABLE_PROMPT_CACHING_1H = "1";
    FORCE_AUTOUPDATE_PLUGINS = "1";
    MCP_TIMEOUT = toString (shared.mcp.timeouts.startup * 1000);
  };
}
