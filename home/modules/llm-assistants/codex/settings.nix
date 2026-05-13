# ==============================================================================
# Codex Settings
# ==============================================================================

{
  agents,
  hooks,
  mcp,
  notify,
  skills,
  ...
}:

{
  # ----------------------------------------------------------------------------
  # Model
  # ----------------------------------------------------------------------------
  model = "gpt-5.5";
  model_reasoning_effort = "high";
  model_verbosity = "low";
  personality = "pragmatic";

  # ----------------------------------------------------------------------------
  # Execution
  # ----------------------------------------------------------------------------
  approval_policy = "never";
  sandbox_mode = "danger-full-access";
  shell_environment_policy = {
    "inherit" = "all";
  };

  # ----------------------------------------------------------------------------
  # Project context
  # ----------------------------------------------------------------------------
  project_doc_fallback_filenames = [ "CLAUDE.md" ];

  # ----------------------------------------------------------------------------
  # History / memory
  # ----------------------------------------------------------------------------
  history = {
    persistence = "save-all";
    max_bytes = 268435456; # 256 MB
  };

  memories = {
    generate_memories = true;
    use_memories = true;
    disable_on_external_context = true;
    min_rollout_idle_hours = 24;
    max_rollouts_per_startup = 6;
    max_raw_memories_for_consolidation = 50;
  };

  # ----------------------------------------------------------------------------
  # Tools / search
  # ----------------------------------------------------------------------------
  web_search = "live";
  tools = {
    view_image = true;
    web_search.context_size = "high";
  };

  # ----------------------------------------------------------------------------
  # Agents
  # ----------------------------------------------------------------------------
  agents = agents.settings;

  # ----------------------------------------------------------------------------
  # Hooks
  # ----------------------------------------------------------------------------
  inherit hooks;

  # ----------------------------------------------------------------------------
  # MCP servers
  # ----------------------------------------------------------------------------
  mcp_servers = mcp.serversConfig;

  # ----------------------------------------------------------------------------
  # Skills
  # ----------------------------------------------------------------------------
  skills = skills.settings;

  # ----------------------------------------------------------------------------
  # Interface
  # ----------------------------------------------------------------------------
  notify = [
    "${notify.mkProjectNotifyScript}"
    "Codex"
    "Response complete"
  ];

  tui = {
    status_line = [
      "current-dir"
      "git-branch"
      "model-with-reasoning"
      "context-used"
      "five-hour-limit"
      "weekly-limit"
      "pull-request-number"
      "run-state"
      "thread-title"
      "task-progress"
    ];
    status_line_use_colors = true;
  };

  # ----------------------------------------------------------------------------
  # Notices
  # ----------------------------------------------------------------------------
  notice = {
    fast_default_opt_out = true;
  };

  # ----------------------------------------------------------------------------
  # Features
  # ----------------------------------------------------------------------------
  suppress_unstable_features_warning = true;
  features = {
    goals = true;
    hooks = true;
    memories = true;
    prevent_idle_sleep = true;
    terminal_resize_reflow = true;
  };
}
