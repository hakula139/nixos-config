# ==============================================================================
# OMP Settings
# ==============================================================================

{
  # ----------------------------------------------------------------------------
  # Appearance
  # ----------------------------------------------------------------------------
  symbolPreset = "nerd";
  composer.shape = "band";
  theme.dark = "titanium";

  statusLine = {
    preset = "custom";
    leftSegments = [
      "model"
      "mode"
      "subagents"
      "path"
      "git"
    ];
    rightSegments = [
      "context_pct"
      "cost"
      "token_rate"
    ];
    separator = "pipe";
    compactThinkingLevel = false;
    sessionAccent = false;
    transparent = true;
    segmentOptions = {
      model.showThinkingLevel = true;
      path = {
        abbreviate = true;
        maxLength = 28;
        stripWorkPrefix = true;
      };
      git = {
        showBranch = true;
        showStaged = true;
        showUnstaged = true;
        showUntracked = true;
      };
    };
  };

  # ----------------------------------------------------------------------------
  # Interaction
  # ----------------------------------------------------------------------------
  startup = {
    checkUpdate = false;
    setupWizard = false;
  };

  followUpMode = "all";
  personality = "none";
  steeringMode = "all";

  ask.timeout = 0;

  providers = {
    cacheRetention = "long";
    streamFirstEventTimeoutSeconds = 1800;
    streamIdleTimeoutSeconds = 0;
  };

  # ----------------------------------------------------------------------------
  # Memory
  # ----------------------------------------------------------------------------
  checkpoint.enabled = true;
  memory.backend = "local";
  autolearn.enabled = true;

  # ----------------------------------------------------------------------------
  # Agents
  # ----------------------------------------------------------------------------
  task = {
    eager = "preferred";
    enableEffort = true;
    enableLsp = true;
    maxConcurrency = 8;
    maxRecursionDepth = 3;
    maxRuntimeMs = 1800000;

    isolation.enabled = true;
  };

  # ----------------------------------------------------------------------------
  # Editing
  # ----------------------------------------------------------------------------
  astGrep.enabled = true;

  lsp = {
    formatOnWrite = true;
    diagnosticsOnEdit = true;
  };

  github.enabled = true;

  # ----------------------------------------------------------------------------
  # Search
  # ----------------------------------------------------------------------------
  providers.webSearchOrder = [ "exa" ];

  # ----------------------------------------------------------------------------
  # Speech generation
  # ----------------------------------------------------------------------------
  speechgen.enabled = true;
  providers.tts = "local";

  # ----------------------------------------------------------------------------
  # Privacy
  # ----------------------------------------------------------------------------
  secrets.enabled = true;
}
