# ==============================================================================
# Claude Code Auth Profiles — public subset
# ==============================================================================
# Decryptable by every agenix recipient (secrets are `allKeys`-scoped).
# Corp profiles live in `lib/claude-profiles-corp.nix`; hosts with workstation-
# level secret access layer them in on top.
# ==============================================================================

{
  official = {
    type = "subscription";
  };

  official-token = {
    type = "oauth-token";
    tokenSecret = "llm-assistants/claude-oauth-token";
  };

  ikuncode = {
    type = "api-key";
    tokenSecret = "llm-assistants/ikuncode-api-key";
    baseUrl = "https://api.ikuncode.cc";
  };

  yescode = {
    type = "api-key";
    tokenSecret = "llm-assistants/yescode-api-key";
    baseUrl = "https://co.yes.vg";
  };
}
