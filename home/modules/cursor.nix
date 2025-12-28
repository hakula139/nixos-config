{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

# ==============================================================================
# Cursor Configuration
# ==============================================================================

let
  cfg = config.hakula.cursor;
  isDarwin = pkgs.stdenv.isDarwin;

  marketplace = inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace;
  vscExtLib = pkgs.vscode-extensions;

  # ----------------------------------------------------------------------------
  # Settings Generation
  # ----------------------------------------------------------------------------
  cursorSettingsBase = builtins.fromJSON (builtins.readFile ../cursor/settings.json);
  cursorSettingsOverrides = import ../cursor/settings.nix { inherit pkgs; };
  cursorSettings = lib.recursiveUpdate cursorSettingsBase cursorSettingsOverrides;
  cursorSettingsJson = (pkgs.formats.json { }).generate "cursor-settings.json" cursorSettings;

  # ----------------------------------------------------------------------------
  # User Files (settings, keybindings, snippets)
  # ----------------------------------------------------------------------------
  cursorUserFiles =
    if isDarwin then
      # ~/...
      {
        "Library/Application Support/Cursor/User/settings.json".source = cursorSettingsJson;
        "Library/Application Support/Cursor/User/keybindings.json".source = ../cursor/keybindings.json;
        "Library/Application Support/Cursor/User/snippets".source = ../cursor/snippets;
      }
    else
      # ~/.config/...
      {
        "Cursor/User/settings.json".source = cursorSettingsJson;
        "Cursor/User/keybindings.json".source = ../cursor/keybindings.json;
        "Cursor/User/snippets".source = ../cursor/snippets;
      };

  # ----------------------------------------------------------------------------
  # Extension List
  # ----------------------------------------------------------------------------
  extensions = with vscExtLib; [
    # --------------------------------------------------------------------------
    # C/C++
    # --------------------------------------------------------------------------
    ms-vscode.cpptools
    llvm-vs-code-extensions.vscode-clangd
    vadimcn.vscode-lldb
    ms-vscode.cmake-tools

    # --------------------------------------------------------------------------
    # Python
    # --------------------------------------------------------------------------
    ms-python.python
    ms-python.vscode-pylance
    ms-python.debugpy
    charliermarsh.ruff

    # --------------------------------------------------------------------------
    # Web Development
    # --------------------------------------------------------------------------
    vue.volar
    dbaeumer.vscode-eslint
    esbenp.prettier-vscode
    bradlc.vscode-tailwindcss

    # --------------------------------------------------------------------------
    # Go
    # --------------------------------------------------------------------------
    golang.go

    # --------------------------------------------------------------------------
    # Rust
    # --------------------------------------------------------------------------
    rust-lang.rust-analyzer

    # --------------------------------------------------------------------------
    # Haskell
    # --------------------------------------------------------------------------
    haskell.haskell
    marketplace.phoityne.phoityne-vscode

    # --------------------------------------------------------------------------
    # Other Languages
    # --------------------------------------------------------------------------
    jnoortheen.nix-ide
    foxundermoon.shell-format
    redhat.vscode-yaml
    tamasfe.even-better-toml
    mechatroner.rainbow-csv
    samuelcolvin.jinjahtml
    myriad-dreamin.tinymist
    zxh404.vscode-proto3

    # --------------------------------------------------------------------------
    # Remote Development
    # --------------------------------------------------------------------------
    ms-vscode-remote.vscode-remote-extensionpack
    ms-vscode-remote.remote-ssh-edit
    ms-vscode.remote-explorer
    ms-vscode.live-server

    # --------------------------------------------------------------------------
    # Containers & Kubernetes
    # --------------------------------------------------------------------------
    docker.docker
    ms-azuretools.vscode-docker
    ms-kubernetes-tools.vscode-kubernetes-tools

    # --------------------------------------------------------------------------
    # Git & GitHub
    # --------------------------------------------------------------------------
    eamodio.gitlens
    github.vscode-github-actions

    # --------------------------------------------------------------------------
    # Markdown & Documentation
    # --------------------------------------------------------------------------
    shd101wyy.markdown-preview-enhanced
    davidanson.vscode-markdownlint
    yzhang.markdown-all-in-one
    marp-team.marp-vscode
    james-yu.latex-workshop

    # --------------------------------------------------------------------------
    # Utilities & Tools
    # --------------------------------------------------------------------------
    streetsidesoftware.code-spell-checker
    usernamehw.errorlens
    hediet.vscode-drawio
    wakatime.vscode-wakatime

    # --------------------------------------------------------------------------
    # Themes
    # --------------------------------------------------------------------------
    marketplace.t3dotgg.vsc-material-theme-but-i-wont-sue-you
    pkief.material-icon-theme
  ];

  # ----------------------------------------------------------------------------
  # Extension Installation Scripts
  # ----------------------------------------------------------------------------
  mkExtensionCopyScript =
    ext:
    let
      extId = ext.vscodeExtPublisher + "." + ext.vscodeExtName;
      version = ext.version;
      src = "${ext}/share/vscode/extensions/${extId}";
      dest = "$HOME/.cursor/extensions/${extId}-${version}";
    in
    ''
      # Remove old versions of this extension
      for old in "$base/${extId}"-*; do
        if [ -e "$old" ] && [ "$old" != "${dest}" ]; then
          rm -rf "$old"
        fi
      done

      # Copy extension if not already present
      if [ ! -e "${dest}" ]; then
        cp -R "${src}" "${dest}"
        chmod -R u+rw,go-rwx "${dest}"
      fi
    '';

  extensionCopyScripts = lib.concatMapStringsSep "\n\n" mkExtensionCopyScript extensions;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.cursor = {
    enable = lib.mkEnableOption "Cursor configuration";

    enableExtensions = lib.mkEnableOption "Cursor extensions";
  };

  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # User Configuration Files
    # --------------------------------------------------------------------------
    xdg.configFile = lib.optionalAttrs (!isDarwin) cursorUserFiles;
    home.file = lib.optionalAttrs isDarwin cursorUserFiles;

    # --------------------------------------------------------------------------
    # Extension Installation (Home Manager Activation)
    # --------------------------------------------------------------------------
    home.activation.cursorExtensions = lib.mkIf cfg.enableExtensions (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        base="$HOME/.cursor/extensions"
        mkdir -p "$base"

        ${extensionCopyScripts}
      ''
    );
  };
}
