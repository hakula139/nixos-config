# ==================================================================================================
# Codex Plugins
# ==================================================================================================

{
  pkgs,
  lib,
}:

{
  settings = lib.optionalAttrs pkgs.stdenv.isDarwin {
    plugins = {
      "browser@openai-bundled".enabled = true;
      "chrome@openai-bundled".enabled = true;
      "code-review@openai-bundled".enabled = false;
      "codex-app-tools@openai-bundled".enabled = true;
      "computer-history@openai-bundled".enabled = true;
      "computer-use@openai-bundled".enabled = true;
      "documents@openai-primary-runtime".enabled = true;
      "pdf@openai-primary-runtime".enabled = true;
      "presentations@openai-primary-runtime".enabled = true;
      "spreadsheets@openai-primary-runtime".enabled = true;
      "template-creator@openai-primary-runtime".enabled = true;
      "visualize@openai-bundled".enabled = true;
    };
  };
}
