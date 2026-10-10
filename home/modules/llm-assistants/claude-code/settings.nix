# ==================================================================================================
# Claude Code Settings
# ==================================================================================================

{
  lib,
  homeDir,
  hooks,
  permissionSettings,
  plugins,
  bundlePlugins,
  profileSettings,
  preferences,
  timeouts,
}:

{
  inherit hooks;
  inherit (plugins) enabledPlugins;
}
// permissionSettings
// profileSettings
// lib.optionalAttrs (!bundlePlugins) {
  # With bundling, known_marketplaces.json drives discovery, and leaving extraKnownMarketplaces set
  # triggers failed GitHub installs offline.
  inherit (plugins) extraKnownMarketplaces;
}
// {
  # ------------------------------------------------------------------------------------------------
  # Project
  # ------------------------------------------------------------------------------------------------
  plansDirectory = "./${preferences.plansDir}";

  includeGitInstructions = false;
  attribution = {
    commit = "";
    pr = "";
  };

  # ------------------------------------------------------------------------------------------------
  # Interface
  # ------------------------------------------------------------------------------------------------
  theme = "dark";
  tui = "fullscreen";
  statusLine = {
    type = "command";
    command = "${homeDir}/.claude/statusline-command";
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
    .${toString preferences.askTimeout};

  # ------------------------------------------------------------------------------------------------
  # Environment
  # ------------------------------------------------------------------------------------------------
  env = {
    API_FORCE_IDLE_TIMEOUT = "0";
    API_TIMEOUT_MS = "1800000";
    CLAUDE_CODE_AUTO_MODE_SERVER = "0";
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
    CLAUDE_CODE_ENABLE_AUTO_MODE = "1";
    CLAUDE_CODE_ENABLE_TODO_TOOLS = "1";
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    CLAUDE_CODE_SCROLL_SPEED = "1";
    DISABLE_INSTALLATION_CHECKS = "1";
    ENABLE_CLAUDEAI_MCP_SERVERS = "0";
    ENABLE_PROMPT_CACHING_1H = "1";
    FORCE_AUTOUPDATE_PLUGINS = if bundlePlugins then "0" else "1";
    MCP_TIMEOUT = toString (timeouts.startup * 1000);
  };
}
