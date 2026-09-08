# ==============================================================================
# Shared LLM Assistant Modules
# ==============================================================================

{
  config,
  pkgs,
  lib,
  corpHosts,
  proxyLib,
  repo,
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
      inherit
        config
        pkgs
        lib
        corpHosts
        proxyLib
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
