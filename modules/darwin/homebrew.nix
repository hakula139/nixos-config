# ==============================================================================
# Homebrew Packages
# ==============================================================================

{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "none";
      upgrade = true;
    };
    taps = [ ];
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
      "onyx"
      "qq"
      "rectangle"
      "steam"
      "telegram"
      "tencent-lemon"
      "tencent-meeting"
      "tor-browser"
      "warp"
      "wechat"
      "windows-app"
    ];
    masApps = {
      "AdGuard for Safari" = 1440147259;
      Bitwarden = 1352778147;
      Keynote = 409183694;
      Numbers = 409203825;
      Pages = 409201541;
      "Steam Link" = 1246969117;
      Userscripts = 1463298887;
      Xcode = 497799835;
    };
  };
}
