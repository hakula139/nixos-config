# ==============================================================================
# Linux workstation System Manager profile
# ==============================================================================

{
  config,
  secrets,
  ...
}:

let
  corpDomain = import ../../../lib/corp-domain.nix;

  user = config.hakula.user.name;
  userCfg = config.users.users.${user};

  workstationSecrets = secrets.mkUserSecrets {
    names = [
      "mihomo/subscription-url"
      "mihomo/secret"
      "wakatime/config"
    ];
    user = userCfg;
    overrides.wakatime-config.path = "${userCfg.home}/.wakatime.cfg";
  };
in
{
  # ----------------------------------------------------------------------------
  # Home Manager Profile
  # ----------------------------------------------------------------------------
  home-manager.users.${user}.imports = [
    ../workstation-linux-home
  ];

  # ----------------------------------------------------------------------------
  # Assistant Tooling
  # ----------------------------------------------------------------------------
  hakula.llm-assistants = {
    enable = true;
    proxy = {
      enable = true;
      noProxy = [
        "localhost"
        "127.0.0.1"
        "10.*"
        ".${corpDomain}"
      ];
    };
  };

  hakula.claude-code.defaultProfile = "corp-gateway";

  # ----------------------------------------------------------------------------
  # Workstation Secrets
  # ----------------------------------------------------------------------------
  age.secrets = workstationSecrets;
}
