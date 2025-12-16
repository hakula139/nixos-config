{
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Darwin (macOS) Environment
# ==============================================================================

lib.mkIf pkgs.stdenv.isDarwin {
  home.sessionVariables = {
    # --------------------------------------------------------------------------
    # Homebrew Mirrors
    # --------------------------------------------------------------------------
    HOMEBREW_API_DOMAIN = "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api";
    HOMEBREW_BOTTLE_DOMAIN = "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles";
  };

  home.sessionPath = [
    "/opt/homebrew/bin" # Homebrew (Apple Silicon)
  ];

  programs.zsh.initContent = lib.mkAfter ''
    # ==========================================================================
    # macOS-specific Shell Configuration
    # ==========================================================================

    # --------------------------------------------------------------------------
    # Homebrew Environment
    # --------------------------------------------------------------------------
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    # --------------------------------------------------------------------------
    # Java (macOS java_home helper)
    # This uses macOS's java_home to find installed JDKs
    # On Linux, JAVA_HOME is set differently (usually by the package)
    # --------------------------------------------------------------------------
    if /usr/libexec/java_home &>/dev/null 2>&1; then
      export JAVA_HOME="$(/usr/libexec/java_home)"
      export PATH="$JAVA_HOME/bin:$PATH"
    fi
  '';
}
