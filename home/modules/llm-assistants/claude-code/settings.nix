# ==============================================================================
# Claude Code Settings
# ==============================================================================

{
  lib,
  homeDir,
  hooks,
  permissions,
  sharedPermissions,
  plugins,
  bundlePlugins,
  profileSettings,
  timeouts,
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
  # Project
  # ----------------------------------------------------------------------------
  plansDirectory = "./.agents/plans";
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
    soft_deny = [
      "$defaults"
    ]
    ++ sharedPermissions.claudeSoftDeny
    ++ [
      "GitHub / GitLab MCP writes [named+specifics — **must name:** the action and its target]: Any `mcp__GitHub__*` or `mcp__GitLab__*` tool call that changes remote state, including publishing (branches, files, commits, repositories, forks, issues, pull / merge requests, labels, commit statuses), merging, commenting or reacting, reviewing or approving, requesting reviews or assigning Copilot, changing project or branch-protection settings, remote deletion, and pipeline control (creating, retrying, cancelling, or playing pipelines and jobs). Clears only when the user's own message in this conversation asked for this action. No allow exception clears it."
    ];
  };

  # ----------------------------------------------------------------------------
  # Environment
  # ----------------------------------------------------------------------------
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
