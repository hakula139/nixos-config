{
  lib,
  prune ? false,
  ...
}:

# ==============================================================================
# Cursor Extensions
# ==============================================================================

let
  # ----------------------------------------------------------------------------
  # Extension List
  # ----------------------------------------------------------------------------
  baseExtensions = [
    # --------------------------------------------------------------------------
    # AI
    # --------------------------------------------------------------------------
    "anthropic.claude-code"

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
    "ms-toolsai.jupyter"
    "ms-toolsai.jupyter-renderers"
    "ms-toolsai.vscode-jupyter-cell-tags"
    "ms-toolsai.vscode-jupyter-slideshow"

    # --------------------------------------------------------------------------
    # Web Development
    # --------------------------------------------------------------------------
    "vue.volar"
    "dbaeumer.vscode-eslint"
    "esbenp.prettier-vscode"
    "bradlc.vscode-tailwindcss"
    "ms-vscode.live-server"

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
    "justusadam.language-haskell"

    # --------------------------------------------------------------------------
    # Other Languages
    # --------------------------------------------------------------------------
    "drblury.protobuf-vsc"
    "jnoortheen.nix-ide"
    "mads-hartmann.bash-ide-vscode"
    "mechatroner.rainbow-csv"
    "myriad-dreamin.tinymist"
    "redhat.vscode-xml"
    "redhat.vscode-yaml"
    "samuelcolvin.jinjahtml"
    "tamasfe.even-better-toml"

    # --------------------------------------------------------------------------
    # Containers & Kubernetes
    # --------------------------------------------------------------------------
    "docker.docker"
    "ms-azuretools.vscode-containers"
    "ms-azuretools.vscode-docker"
    "ms-kubernetes-tools.vscode-kubernetes-tools"

    # --------------------------------------------------------------------------
    # Git
    # --------------------------------------------------------------------------
    "eamodio.gitlens"
    "github.vscode-github-actions"
    "gitlab.gitlab-workflow"

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

    # --------------------------------------------------------------------------
    # Themes
    # --------------------------------------------------------------------------
    "t3dotgg.vsc-material-theme-but-i-wont-sue-you"
    "pkief.material-icon-theme"
  ];

  remoteExtensions = [
    # --------------------------------------------------------------------------
    # Remote Development
    # --------------------------------------------------------------------------
    "anysphere.remote-containers"
    "anysphere.remote-ssh"
    "anysphere.remote-wsl"
    "ms-vscode.remote-explorer"
    "ms-vscode-remote.remote-ssh-edit"

    # --------------------------------------------------------------------------
    # Utilities & Tools
    # --------------------------------------------------------------------------
    "wakatime.vscode-wakatime"
  ];

  # ----------------------------------------------------------------------------
  # Installation Script
  # ----------------------------------------------------------------------------
  installScript = ''
    is_cursor_server() {
      [[ "$(command -v cursor 2>/dev/null)" == *".cursor-server"* ]]
    }

    base_extensions="${lib.concatStringsSep "\n" baseExtensions}"
    remote_extensions="${lib.concatStringsSep "\n" remoteExtensions}"

    if is_cursor_server; then
      expected="$base_extensions"
    else
      expected="$base_extensions"$'\n'"$remote_extensions"
    fi

    get_installed_ids() {
      cursor --list-extensions --show-versions 2>/dev/null \
        | sed 's/\r$//' \
        | grep -E '^[[:alnum:]_-]+\.[[:alnum:]_-]+(@[^[:space:]]+)?$' \
        | cut -d@ -f1
    }

    installed_ids="$(get_installed_ids)"

    # Install missing extensions
    while IFS= read -r ext; do
      [ -z "$ext" ] && continue
      printf '%s\n' "$installed_ids" | grep -iqFx "$ext" && continue
      cursor --install-extension "$ext" || true
    done < <(printf '%s\n' "$expected")

    # Prune non-provisioned extensions
    if ${lib.boolToString prune}; then
      while IFS= read -r ext; do
        [ -z "$ext" ] && continue
        printf '%s\n' "$expected" | grep -iqFx "$ext" && continue
        cursor --uninstall-extension "$ext" 2>/dev/null || true
      done < <(get_installed_ids)
    fi
  '';
in
{
  inherit installScript;
}
