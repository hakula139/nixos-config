# ==================================================================================================
# DevVM Host Configuration
# ==================================================================================================

{
  lib,
  corpHosts,
  keys,
  repo,
  ...
}:

let
  inherit (corpHosts) wildcardDomain;

  proxyUrlSecret = "devvm/proxy-url";
  proxyNoProxy = [
    wildcardDomain
  ];
in
{
  imports = [
    repo.profiles.platform.container
  ];

  # ------------------------------------------------------------------------------------------------
  # Networking
  # ------------------------------------------------------------------------------------------------
  networking.hostName = "devvm";

  # ------------------------------------------------------------------------------------------------
  # Nix Daemon Proxy
  # ------------------------------------------------------------------------------------------------
  hakula.nix-daemon.proxy = {
    enable = true;
    secretName = proxyUrlSecret;
    noProxy = proxyNoProxy;
  };

  # ------------------------------------------------------------------------------------------------
  # Binary Cache
  # ------------------------------------------------------------------------------------------------
  hakula.nix.caches = [ "hakula" ];

  # ------------------------------------------------------------------------------------------------
  # User Configuration
  # ------------------------------------------------------------------------------------------------
  hakula.user.name = "root";
  hakula.access.ssh.authorizedKeys = lib.attrValues keys.workstations;

  # ------------------------------------------------------------------------------------------------
  # Services
  # ------------------------------------------------------------------------------------------------
  hakula.services.openssh = {
    enable = true;
    ports = [ 2222 ];
  };

  services.openssh = {
    # Persist the host key in the devvm-root volume so container recreations keep the same identity.
    hostKeys = [
      {
        path = "/root/.config/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings.PubkeyAuthentication = true;
  };

  # ------------------------------------------------------------------------------------------------
  # Home Manager Overrides
  # ------------------------------------------------------------------------------------------------
  home-manager.users.root =
    {
      config,
      secretPath,
      ...
    }:
    let
      inherit (config.agents.claude-code.auth) enabledProfiles;
      gatewayProfile = "corp-gateway-hybrid";

      useGatewayProfile =
        config.hakula.llm-assistants.auth.enableCorpGateway
        && (enabledProfiles == null || lib.elem gatewayProfile enabledProfiles);
    in
    {
      # --------------------------------------------------------------------------------------------
      # Nix
      # --------------------------------------------------------------------------------------------
      hakula.nix.configPath = "/root/workspace/gitlab/nixos-config";

      # --------------------------------------------------------------------------------------------
      # Mirrors
      # --------------------------------------------------------------------------------------------
      hakula.corp-mirrors.enable = true;

      # --------------------------------------------------------------------------------------------
      # Assistant Tooling
      # --------------------------------------------------------------------------------------------
      home.sessionVariables.IS_SANDBOX = "1";

      hakula.llm-assistants = {
        enable = lib.mkDefault true;
        mcp.disabledServers = [
          "chromeDevtools"
          "deepwiki"
          "exa"
          "github"
          "scrapling"
        ];
      };

      agents = {
        claude-code.auth.defaultProfile = lib.mkIf useGatewayProfile (lib.mkDefault gatewayProfile);

        proxy = {
          enable = true;
          secretUrlFile = secretPath proxyUrlSecret;
          noProxy = proxyNoProxy;
        };
      };

      # --------------------------------------------------------------------------------------------
      # Secrets
      # --------------------------------------------------------------------------------------------
      hakula.secrets.required.${proxyUrlSecret} = { };

      # --------------------------------------------------------------------------------------------
      # Services
      # --------------------------------------------------------------------------------------------
      # SSH config comes from bind-mounted host ~/.ssh/config.
      programs.ssh.enable = lib.mkForce false;

      services.ssh-agent.enable = lib.mkForce false;
    };

  # ------------------------------------------------------------------------------------------------
  # System State
  # ------------------------------------------------------------------------------------------------
  system.stateVersion = "25.11";
}
