# ==================================================================================================
# earlyoom (Userspace OOM Killer)
# ==================================================================================================

{
  config,
  lib,
  ...
}:

let
  cfg = config.hakula.services.earlyoom;

  coreIgnoreComms = [
    "systemd"
    "dbus-broker"
    "ssh-agent"
    "sshd"
    "tmux"
    "[(]sd-pam[)]"
    "nsncd"
  ];

  # --prefer adds 3 GiB of VmRSS, so a session must be over 3 GiB larger than a listed process to
  # be killed first. List only processes that are cheap to rerun. Each entry matches the whole comm
  # truncated to 15 bytes. `nix-store` is out: a remote store operation only waits on the daemon.
  preferComms = [
    "cargo"
    "cargo-clippy"
    "cc1" # GCC C compiler
    "cc1plus" # GCC C++ compiler
    "clippy-driver"
    "ld.*"
    "nix"
    "rust-lld"
    "rustc"
    "rustdoc"

    "MainThread" # Node.js main thread (Cursor, MCP)
    "node"
    "npm.*"
    "pytest"
    "python.*"
    "uv"
    "vitest"

    "astro"
    "workerd"

    "clangd.*"
    "gopls"
    "harper-ls"
    "nixd"
    "pet" # Python Environment Tools server (VS Code Python extension)
    "ruff"
    "rust-analyzer.*"
    "taplo"

    "gk" # GitKraken CLI MCP server
    "[.]mcp-proxy.*" # MCP proxy Nix wrapper (comm .mcp-proxy-wrap)
    "mcp-server-.*"

    "chrome"
    "chrome-devtools"
    "chrome-headless"
    "chromium"
    "headless_shell"
  ];

  mkIgnore = names: "^(${lib.concatStringsSep "|" names})";
  mkPrefer = names: "^(${lib.concatStringsSep "|" names})$";

  validate = re: builtins.seq (builtins.match re "") re;

  ignoreRegex = validate (mkIgnore cfg.ignoreComms);
  preferRegex = validate (mkPrefer preferComms);
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.services.earlyoom = {
    enable = lib.mkEnableOption "early OOM killer with tiered victim selection";

    freeMemPercent = lib.mkOption {
      type = lib.types.ints.between 1 100;
      default = 10;
      description = ''
        Available memory percentage at or below which earlyoom kills, once free swap is also at
        or below its percentage.
      '';
    };

    freeSwapPercent = lib.mkOption {
      type = lib.types.ints.between 1 100;
      default = 10;
      description = ''
        Available swap percentage at or below which earlyoom kills, once available memory is also
        at or below its percentage.
      '';
    };

    ignoreComms = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Additional comm patterns for the ignore list. Each entry is one POSIX ERE alternative
        matched against comm, truncated to 15 bytes. Ignore entries match a prefix. Write
        literal metacharacters as bracket expressions, because systemd drops backslashes.
      '';
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------------------------
    # Assertions
    # ----------------------------------------------------------------------------------------------
    assertions = [
      {
        assertion = !(lib.hasInfix "\\" ignoreRegex);
        message = "hakula.services.earlyoom.ignoreComms must use bracket expressions.";
      }
    ];

    # ----------------------------------------------------------------------------------------------
    # Ignore list
    # ----------------------------------------------------------------------------------------------
    # Defined here so module contributions concatenate with it.
    hakula.services.earlyoom.ignoreComms = coreIgnoreComms;

    # ----------------------------------------------------------------------------------------------
    # systemd-oomd
    # ----------------------------------------------------------------------------------------------
    systemd.oomd.enable = false;

    # ----------------------------------------------------------------------------------------------
    # Kernel OOM killer
    # ----------------------------------------------------------------------------------------------
    # The kernel otherwise kills the session daemons first, and an unprivileged manager cannot
    # lower their OOMScoreAdjust. Continue keeps a kernel kill inside one user unit, which matters
    # most for tmux's non-delegated scopes.
    systemd.services."user@".serviceConfig.OOMScoreAdjust = 0;
    systemd.user.extraConfig = ''
      DefaultOOMScoreAdjust=0
      DefaultOOMPolicy=continue
    '';

    # ----------------------------------------------------------------------------------------------
    # earlyoom service
    # ----------------------------------------------------------------------------------------------
    services.earlyoom = {
      enable = true;
      freeMemThreshold = cfg.freeMemPercent;
      freeSwapThreshold = cfg.freeSwapPercent;
      extraArgs = [
        "--sort-by-rss"

        "--ignore"
        ignoreRegex
        "--ignore-root-user"

        "--prefer"
        preferRegex
      ];
    };
  };
}
