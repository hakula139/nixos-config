# ==============================================================================
# Darwin (macOS) Environment
# ==============================================================================

{
  pkgs,
  lib,
  ...
}:

lib.mkIf pkgs.stdenv.isDarwin {
  # ----------------------------------------------------------------------------
  # Environment Variables (macOS)
  # ----------------------------------------------------------------------------
  home.sessionVariables = { };

  # ----------------------------------------------------------------------------
  # PATH additions (macOS)
  # ----------------------------------------------------------------------------
  home.sessionPath = [
    "/Applications/Docker.app/Contents/Resources/bin"
    "/opt/homebrew/bin"
  ];

  # ----------------------------------------------------------------------------
  # Cargo Configuration (macOS)
  # ----------------------------------------------------------------------------
  # Use the system linker to avoid SDK mismatch between Nix's cc wrapper
  # (apple-sdk sysroot) and the Rust stdlib (system Xcode SDK).
  home.file.".cargo/config.toml".text = ''
    [target.aarch64-apple-darwin]
    linker = "/usr/bin/cc"
  '';

  # ----------------------------------------------------------------------------
  # Shell Configuration (macOS)
  # ----------------------------------------------------------------------------
  programs.zsh.envExtra = ''
    export LIBRARY_PATH="$(xcrun --show-sdk-path)/usr/lib''${LIBRARY_PATH:+:$LIBRARY_PATH}"
  '';

  programs.zsh.initContent = lib.mkAfter ''
    # --------------------------------------------------------------------------
    # Homebrew Environment
    # --------------------------------------------------------------------------
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  '';
}
