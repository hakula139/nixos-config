# ==============================================================================
# Homebrew Packages
# ==============================================================================

{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "uninstall";
      extraFlags = [ "--force-cleanup" ];
      upgrade = true;
    };
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
      "whatpulse/whatpulse/whatpulse"
    ];
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
}
