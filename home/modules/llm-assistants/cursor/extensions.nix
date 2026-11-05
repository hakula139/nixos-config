# ==================================================================================================
# Cursor Extensions
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  isDarwin,
  repoLib,
}:

let
  cfg = config.hakula.cursor;
  inherit (config.home) username;

  # ------------------------------------------------------------------------------------------------
  # Extension list
  # ------------------------------------------------------------------------------------------------
  baseExtensions = [
    # ----------------------------------------------------------------------------------------------
    # AI
    # ----------------------------------------------------------------------------------------------
    "anthropic.claude-code"

    # ----------------------------------------------------------------------------------------------
    # C/C++
    # ----------------------------------------------------------------------------------------------
    "anysphere.cpptools"
    "llvm-vs-code-extensions.vscode-clangd"
    "vadimcn.vscode-lldb"
    "ms-vscode.cmake-tools"

    # ----------------------------------------------------------------------------------------------
    # Python
    # ----------------------------------------------------------------------------------------------
    "anysphere.cursorpyright"
    "ms-python.python"
    "ms-python.debugpy"
    "charliermarsh.ruff"
    "ms-toolsai.jupyter"
    "ms-toolsai.jupyter-renderers"
    "ms-toolsai.vscode-jupyter-cell-tags"
    "ms-toolsai.vscode-jupyter-slideshow"

    # ----------------------------------------------------------------------------------------------
    # Web development
    # ----------------------------------------------------------------------------------------------
    "vue.volar"
    "dbaeumer.vscode-eslint"
    "esbenp.prettier-vscode"
    "bradlc.vscode-tailwindcss"
    "ms-vscode.live-server"

    # ----------------------------------------------------------------------------------------------
    # Go
    # ----------------------------------------------------------------------------------------------
    "golang.go"

    # ----------------------------------------------------------------------------------------------
    # Rust
    # ----------------------------------------------------------------------------------------------
    "rust-lang.rust-analyzer"

    # ----------------------------------------------------------------------------------------------
    # Haskell
    # ----------------------------------------------------------------------------------------------
    "haskell.haskell"
    "justusadam.language-haskell"

    # ----------------------------------------------------------------------------------------------
    # Other languages
    # ----------------------------------------------------------------------------------------------
    "DrBlury.protobuf-vsc"
    "jnoortheen.nix-ide"
    "mads-hartmann.bash-ide-vscode"
    "mechatroner.rainbow-csv"
    "myriad-dreamin.tinymist"
    "redhat.vscode-xml"
    "redhat.vscode-yaml"
    "samuelcolvin.jinjahtml"
    "tamasfe.even-better-toml"
    "TheNuProjectContributors.vscode-nushell-lang"

    # ----------------------------------------------------------------------------------------------
    # Containers & Kubernetes
    # ----------------------------------------------------------------------------------------------
    "docker.docker"
    "ms-azuretools.vscode-containers"
    "ms-azuretools.vscode-docker"
    "ms-kubernetes-tools.vscode-kubernetes-tools"

    # ----------------------------------------------------------------------------------------------
    # Git
    # ----------------------------------------------------------------------------------------------
    "eamodio.gitlens"
    "github.vscode-github-actions"
    "gitlab.gitlab-workflow"

    # ----------------------------------------------------------------------------------------------
    # Markdown & documentation
    # ----------------------------------------------------------------------------------------------
    "shd101wyy.markdown-preview-enhanced"
    "davidanson.vscode-markdownlint"
    "yzhang.markdown-all-in-one"
    "marp-team.marp-vscode"
    "james-yu.latex-workshop"

    # ----------------------------------------------------------------------------------------------
    # Spell & grammar checker
    # ----------------------------------------------------------------------------------------------
    "elijah-potter.harper"
    "streetsidesoftware.code-spell-checker"
    "streetsidesoftware.code-spell-checker-ancient-greek"
    "streetsidesoftware.code-spell-checker-french"
    "streetsidesoftware.code-spell-checker-german"
    "streetsidesoftware.code-spell-checker-italian"
    "streetsidesoftware.code-spell-checker-latin"

    # ----------------------------------------------------------------------------------------------
    # Utilities & tools
    # ----------------------------------------------------------------------------------------------
    "mkhl.direnv"
    "usernamehw.errorlens"
    "hediet.vscode-drawio"
    "lucien-martijn.parquet-visualizer"

    # ----------------------------------------------------------------------------------------------
    # Themes
    # ----------------------------------------------------------------------------------------------
    "Catppuccin.catppuccin-vsc"
    "Catppuccin.catppuccin-vsc-icons"
  ];

  remoteExtensions = [
    # ----------------------------------------------------------------------------------------------
    # Remote development
    # ----------------------------------------------------------------------------------------------
    "anysphere.remote-containers"
    "anysphere.remote-ssh"
    "anysphere.remote-wsl"
    "ms-vscode.remote-explorer"
    "ms-vscode-remote.remote-ssh-edit"

    # ----------------------------------------------------------------------------------------------
    # Utilities & tools
    # ----------------------------------------------------------------------------------------------
    "wakatime.vscode-wakatime"
  ];

  # ------------------------------------------------------------------------------------------------
  # Sync script
  # ------------------------------------------------------------------------------------------------
  cliDirs =
    if isDarwin then
      [
        "/usr/local/bin"
        "/Applications/Cursor.app/Contents/Resources/app/bin"
      ]
    else
      [
        "/usr/local/bin"
        "/usr/bin"
      ];

  syncExtensions = repoLib.mkNuCommand {
    inherit pkgs;
    name = "sync-cursor-extensions";
    script = ./scripts/sync-extensions.nu;
    runtimeInputs = [ pkgs.coreutils ];

    config = {
      inherit
        baseExtensions
        cliDirs
        remoteExtensions
        username
        ;
      prune = cfg.extensions.prune;
      serverDir = "${config.home.homeDirectory}/.cursor-server/bin";
    };
  };
in
{
  activation = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe syncExtensions}
  '';
}
