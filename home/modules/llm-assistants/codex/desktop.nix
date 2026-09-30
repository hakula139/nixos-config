# ==============================================================================
# Codex Desktop Preferences
# ==============================================================================

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
    composerEnterBehavior = "cmdIfMultiline";
    dock-icon-preference = "codex-system";
    enabled-reasoning-efforts = [
      "low"
      "medium"
      "high"
      "xhigh"
      "ultra"
      "persistent"
      "max"
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
    keepRemoteControlAwakeWhilePluggedIn = true;
    notifications-sound = "default";
    open-link-in-target-preference = "in-app-browser";
    preventSleepWhileRunning = true;
    sansFontSize = 14;
    selected-avatar-id = "codex";
    show-context-window-usage = true;
    usePointerCursors = true;
  };
  plugins = {
    "browser@openai-bundled" = {
      enabled = true;
    };
    "code-review@openai-bundled" = {
      enabled = true;
    };
    "codex-app-tools@openai-bundled" = {
      enabled = true;
    };
    "computer-history@openai-bundled" = {
      enabled = true;
    };
    "computer-use@openai-bundled" = {
      enabled = true;
    };
    "documents@openai-primary-runtime" = {
      enabled = true;
    };
    "pdf@openai-primary-runtime" = {
      enabled = true;
    };
    "presentations@openai-primary-runtime" = {
      enabled = true;
    };
    "spreadsheets@openai-primary-runtime" = {
      enabled = true;
    };
    "template-creator@openai-primary-runtime" = {
      enabled = true;
    };
    "visualize@openai-bundled" = {
      enabled = true;
    };
  };
}
