# ==============================================================================
# Shared LLM Assistant Modules
# ==============================================================================

{
  config,
  pkgs,
  lib,
  corpHosts,
  repo,
  repoLib,
  secretPath,
  enableDevToolchains ? false,
  ...
}:

{
  imports = [
    ./skills
  ];

  lib.llmAssistants = {
    instructions = import ./instructions;
    agentRoles = import ./agent-roles;
    agentRoleOptions = import ./agent-roles/options.nix { inherit lib; };

    mcp = import ./mcp {
      inherit (repoLib.proxy) clearProxyEnv;
      inherit
        config
        pkgs
        lib
        corpHosts
        secretPath
        ;
    };
    mcpSecrets = import ./mcp/secrets.nix;

    notify = import ./notify { inherit pkgs lib; };

    mkHooks = import ./hooks {
      inherit
        pkgs
        lib
        repo
        enableDevToolchains
        ;
    };

    mkProfileSwitch = import ./profile-switch { inherit pkgs lib; };
  };
}
