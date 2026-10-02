# ==============================================================================
# Codex Plugins
# ==============================================================================

{
  pkgs,
  lib,
}:

{
  settings = lib.optionalAttrs pkgs.stdenv.isDarwin {
    plugins =
      lib.genAttrs
        [
          "browser@openai-bundled"
          "chrome@openai-bundled"
          "code-review@openai-bundled"
          "codex-app-tools@openai-bundled"
          "computer-history@openai-bundled"
          "computer-use@openai-bundled"
          "documents@openai-primary-runtime"
          "pdf@openai-primary-runtime"
          "presentations@openai-primary-runtime"
          "spreadsheets@openai-primary-runtime"
          "template-creator@openai-primary-runtime"
          "visualize@openai-bundled"
        ]
        (_: {
          enabled = true;
        });
  };
}
