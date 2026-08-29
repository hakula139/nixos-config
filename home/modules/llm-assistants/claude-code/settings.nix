# ==============================================================================
# Claude Code Settings
# ==============================================================================

{
  lib,
  homeDir,
  bundlePlugins,
  hooks,
  permissions,
  plugins,
  profileSettings,
  ...
}:

{
  inherit hooks permissions;
  inherit (plugins) enabledPlugins;
}
// profileSettings
// lib.optionalAttrs (!bundlePlugins) {
  # With bundling, known_marketplaces.json drives discovery, and leaving
  # extraKnownMarketplaces set triggers failed GitHub installs offline.
  inherit (plugins) extraKnownMarketplaces;
}
// {
  # ----------------------------------------------------------------------------
  # Model
  # ----------------------------------------------------------------------------
  model = "opus[1m]";
  effortLevel = "xhigh";

  # ----------------------------------------------------------------------------
  # Project
  # ----------------------------------------------------------------------------
  plansDirectory = "./.claude/plans";
  attribution = {
    commit = "";
    pr = "";
  };

  # ----------------------------------------------------------------------------
  # Interface
  # ----------------------------------------------------------------------------
  theme = "dark";
  tui = "fullscreen";
  wheelScrollAccelerationEnabled = false;
  statusLine = {
    type = "command";
    command = "${homeDir}/.claude/statusline-command";
  };

  # ----------------------------------------------------------------------------
  # Auto mode
  # ----------------------------------------------------------------------------
  autoMode = {
    environment = [
      "$defaults"
      "Source control: github.com/hakula139 and all repos under it"
    ];
  };

  # ----------------------------------------------------------------------------
  # Environment
  # ----------------------------------------------------------------------------
  env = {
    # Bun's 5-minute fetch idle timeout applies to non-first-party base URLs.
    API_FORCE_IDLE_TIMEOUT = "0";
    API_TIMEOUT_MS = "1800000";
    CLAUDE_CODE_AUTO_COMPACT_WINDOW = "400000";
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
    CLAUDE_CODE_ENABLE_AUTO_MODE = "1";
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    CLAUDE_CODE_SCROLL_SPEED = "1";
    DISABLE_INSTALLATION_CHECKS = "1";
    ENABLE_CLAUDEAI_MCP_SERVERS = "0";
    ENABLE_PROMPT_CACHING_1H = "1";
    ENABLE_TOOL_SEARCH = "1";
    FORCE_AUTOUPDATE_PLUGINS = if bundlePlugins then "0" else "1";
  };
}
