# ==================================================================================================
# Context7 Configuration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  secretPath,
  ...
}:

lib.mkIf config.hakula.llm-assistants.enable {
  hakula.secrets.required."llm-assistants/mcp/context7-api-key" = { };

  home.packages = [
    (repoLib.wrapPackage {
      inherit pkgs;
      pkg = pkgs.unstable.ctx7;
      envFiles.CONTEXT7_API_KEY = secretPath "llm-assistants/mcp/context7-api-key";
    })
  ];
}
