{ lib, ... }:

# ==============================================================================
# Cursor Extensions
# ==============================================================================

let
  # ============================================================================
  # Extension List
  # ============================================================================
  extensions = [
    # --------------------------------------------------------------------------
    # C/C++
    # --------------------------------------------------------------------------
    "anysphere.cpptools"
    "llvm-vs-code-extensions.vscode-clangd"
    "vadimcn.vscode-lldb"
    "ms-vscode.cmake-tools"

    # --------------------------------------------------------------------------
    # Python
    # --------------------------------------------------------------------------
    "anysphere.cursorpyright"
    "ms-python.python"
    "ms-python.debugpy"
    "charliermarsh.ruff"

    # --------------------------------------------------------------------------
    # Web Development
    # --------------------------------------------------------------------------
    "vue.volar"
    "dbaeumer.vscode-eslint"
    "esbenp.prettier-vscode"
    "bradlc.vscode-tailwindcss"

    # --------------------------------------------------------------------------
    # Go
    # --------------------------------------------------------------------------
    "golang.go"

    # --------------------------------------------------------------------------
    # Rust
    # --------------------------------------------------------------------------
    "rust-lang.rust-analyzer"

    # --------------------------------------------------------------------------
    # Haskell
    # --------------------------------------------------------------------------
    "haskell.haskell"
    "phoityne.phoityne-vscode"

    # --------------------------------------------------------------------------
    # Other Languages
    # --------------------------------------------------------------------------
    "jnoortheen.nix-ide"
    "mads-hartmann.bash-ide-vscode"
    "redhat.vscode-yaml"
    "tamasfe.even-better-toml"
    "mechatroner.rainbow-csv"
    "samuelcolvin.jinjahtml"
    "myriad-dreamin.tinymist"
    "zxh404.vscode-proto3"

    # --------------------------------------------------------------------------
    # Remote Development
    # --------------------------------------------------------------------------
    "anysphere.remote-containers"
    "anysphere.remote-ssh"
    "anysphere.remote-wsl"
    "ms-vscode-remote.vscode-remote-extensionpack"
    "ms-vscode-remote.remote-ssh-edit"
    "ms-vscode.remote-explorer"
    "ms-vscode.live-server"

    # --------------------------------------------------------------------------
    # Containers & Kubernetes
    # --------------------------------------------------------------------------
    "docker.docker"
    "ms-azuretools.vscode-docker"
    "ms-kubernetes-tools.vscode-kubernetes-tools"

    # --------------------------------------------------------------------------
    # Git & GitHub
    # --------------------------------------------------------------------------
    "eamodio.gitlens"
    "github.vscode-github-actions"

    # --------------------------------------------------------------------------
    # Markdown & Documentation
    # --------------------------------------------------------------------------
    "shd101wyy.markdown-preview-enhanced"
    "davidanson.vscode-markdownlint"
    "yzhang.markdown-all-in-one"
    "marp-team.marp-vscode"
    "james-yu.latex-workshop"

    # --------------------------------------------------------------------------
    # Utilities & Tools
    # --------------------------------------------------------------------------
    "streetsidesoftware.code-spell-checker"
    "usernamehw.errorlens"
    "hediet.vscode-drawio"
    "wakatime.vscode-wakatime"

    # --------------------------------------------------------------------------
    # Themes
    # --------------------------------------------------------------------------
    "t3dotgg.vsc-material-theme-but-i-wont-sue-you"
    "pkief.material-icon-theme"
  ];

  deprecatedExtensions = [
    "foxundermoon.shell-format"
  ];

  # ============================================================================
  # Installation Script
  # ============================================================================
  installScript = ''
    installed="$(cursor --list-extensions --show-versions 2>/dev/null || true)"

    is_installed() {
      case "$1" in
        *@*) printf '%s\n' "$installed" | grep -qFx "$1" ;;
        *) printf '%s\n' "$installed" | cut -d@ -f1 | grep -qFx "$1" ;;
      esac
    }

    while IFS= read -r ext; do
      if [ -n "$ext" ] && ! is_installed "$ext"; then
        cursor --install-extension "$ext" || echo "Failed to install $ext"
      fi
    done <<EOF
    ${lib.concatStringsSep "\n" extensions}
    EOF

    while IFS= read -r ext; do
      if [ -n "$ext" ] && is_installed "$ext"; then
        cursor --uninstall-extension "$ext" >/dev/null 2>&1 || true
      fi
    done <<EOF
    ${lib.concatStringsSep "\n" deprecatedExtensions}
    EOF
  '';
in
{
  inherit extensions installScript;
}
