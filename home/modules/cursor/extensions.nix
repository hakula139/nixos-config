{
  lib,
}:

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
    "foxundermoon.shell-format"
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

  # ============================================================================
  # Installation Script
  # ============================================================================
  installScript = lib.concatMapStringsSep "\n" (ext: ''
    cursor --install-extension "${ext}" || echo "Failed to install ${ext}"
  '') extensions;
in
{
  inherit extensions installScript;
}
