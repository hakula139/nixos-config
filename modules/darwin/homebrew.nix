# ==============================================================================
# Homebrew Packages
# ==============================================================================

{
  config,
  pkgs,
  lib,
  ...
}:

let
  esc = lib.escapeShellArg;
in
{
  # ----------------------------------------------------------------------------
  # Homebrew configuration
  # ----------------------------------------------------------------------------
  homebrew = {
    enable = true;

    # --------------------------------------------------------------------------
    # Activation policy
    # --------------------------------------------------------------------------
    onActivation = {
      autoUpdate = true;
      cleanup = "uninstall";
      extraFlags = [ "--force-cleanup" ];
      upgrade = true;
    };

    # --------------------------------------------------------------------------
    # Packages
    # --------------------------------------------------------------------------
    taps = [ "whatpulse/whatpulse" ];
    brews = [ ];
    casks = [
      "altserver"
      "chatgpt"
      "clash-verge-rev"
      "cursor"
      "docker-desktop"
      "free-download-manager"
      "google-chrome"
      "karabiner-elements"
      "keyclu"
      "latest"
      "mongodb-compass"
      "mos"
      "notion"
      "obs"
      "onedrive"
      "qq"
      "rectangle"
      "steam"
      "telegram"
      "tencent-lemon"
      "tencent-meeting"
      "tor-browser"
      "warp"
      "whatpulse/whatpulse/whatpulse_chmodbpf"
      "whatpulse/whatpulse/whatpulse"
    ];

    # --------------------------------------------------------------------------
    # App Store apps
    # --------------------------------------------------------------------------
    masApps = {
      "AdGuard for Safari" = 1440147259;
      Bitwarden = 1352778147;
      "Dark Reader for Safari" = 1438243180;
      Keynote = 409183694;
      Numbers = 409203825;
      Pages = 409201541;
      "Steam Link" = 1246969117;
      Userscripts = 1463298887;
      WeChat = 836500024;
      "Windows App" = 1295203466;
      Xcode = 497799835;
    };
  };

  # ----------------------------------------------------------------------------
  # Activation
  # ----------------------------------------------------------------------------
  system.activationScripts.homebrew.text = lib.mkForce ''
    run_homebrew_bundle() {
      PATH=${esc "${config.homebrew.prefix}/bin:${lib.makeBinPath [ pkgs.mas ]}"}:"$PATH" \
        sudo \
          --preserve-env=PATH \
          --user=${esc config.homebrew.user} \
          --set-home \
          env \
          ${config.homebrew.onActivation.brewBundleCmd}
    }

    echo >&2 "Homebrew bundle..."
    if [ -f ${esc "${config.homebrew.prefix}/bin/brew"} ]; then
      if ! run_homebrew_bundle; then
        printf >&2 '%s\n' \
          'warning: Homebrew bundle failed. Continuing system activation with incomplete Homebrew package changes.'
      fi
    else
      printf >&2 '%s\n' \
        'warning: Homebrew is not installed. Skipping Homebrew package changes.'
    fi
  '';
}
