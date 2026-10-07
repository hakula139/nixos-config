# ==============================================================================
# Codex Desktop Preferences
# ==============================================================================

{
  homeDirectory,
}:
{
  desktop = {
    agent-usage-reset-enabled = true;
    appearanceDarkChromeTheme = {
      accent = "#0169cc";
      accentSource = "custom";
      contrast = 50;
      fonts = {
        code = "\"Maple Mono NF CN\"";
      };
      ink = "#fcfcfc";
      opaqueWindows = false;
      semanticColors = {
        diffAdded = "#00a240";
        diffRemoved = "#e02e2a";
        skill = "#b06dff";
      };
      surface = "#111111";
    };
    appearanceDarkCodeThemeId = "codex";
    avatar-overlay-pet-visible = false;
    browser-show-full-url = true;
    codeFontSize = 14;
    composerEnterBehavior = "cmdAlways";
    dock-icon-preference = "codex-system";
    enabled-reasoning-efforts = [
      "low"
      "medium"
      "high"
      "xhigh"
      "max"
      "ultra"
      "persistent"
    ];
    external-agent-import-sync-enabled = true;
    external-agent-import-sync-item-types = {
      CONFIG = "original";
      HOOKS = "original";
      MCP_SERVER_CONFIG = "original";
      PLUGINS = "original";
      SESSIONS = "original";
      SKILLS = "original";
    };
    followUpQueueMode = "steer";
    git-pull-request-merge-method = "squash";
    hotkey-window-projectless-default-enabled = true;
    keepRemoteControlAwakeWhilePluggedIn = true;
    notifications-sound = "default";
    open-link-in-target-preference = "in-app-browser";
    preventSleepWhileRunning = true;
    projectlessWorkspaceRoot = "${homeDirectory}/Codex";
    sansFontSize = 14;
    selected-avatar-id = "codex";
    show-context-window-usage = true;
    usePointerCursors = true;
    worktree-upstream-refresh-mode = "best-effort";
  };
  features = {
    chronicle = true;
  };
}
