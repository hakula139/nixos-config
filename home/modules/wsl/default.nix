# ==============================================================================
# WSL Workstation Bundle
# ==============================================================================
# Shared Home Manager bundle for WSL workstation hosts. Imported by the
# `wsl` (NixOS-WSL) and `wsl-non-nixos` (system-manager-on-Ubuntu-WSL) leaves.
# Mihomo and the local proxy stay defined here so per-host opt-in is one
# line, but they're disabled by default — each host enables them only if
# the corp-gateway flow is wanted.
# ==============================================================================

{
  config,
  lib,
  corpDomain,
  ...
}:

let
  cfg = config.hakula.wsl;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.wsl = {
    enable = lib.mkEnableOption "Hakula's WSL workstation Home Manager bundle";
  };

  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Claude Code (corp-gateway profile)
    # --------------------------------------------------------------------------
    # Plain assignment (no `mkDefault`) here: the system-side
    # `hakula.claude-code` module already propagates `defaultProfile` to HM
    # with `mkDefault`, so wrapping ours collides at the same priority.
    # The corp-gateway choice is also the bundle's contract — leaves that
    # need something else can `mkForce`.
    hakula.claude-code.auth = {
      defaultProfile = "corp-gateway";
      enableCorpGateway = true;
    };

    # --------------------------------------------------------------------------
    # Cursor
    # --------------------------------------------------------------------------
    # Disable extension pruning so VSCode-marketplace extensions installed
    # outside Nix (e.g. corp-internal extensions) survive `nixsw`.
    hakula.cursor.extensions.prune = lib.mkForce false;

    # --------------------------------------------------------------------------
    # Fonts (Windows host sync)
    # --------------------------------------------------------------------------
    hakula.fonts.windowsSync.enable = lib.mkDefault true;

    # --------------------------------------------------------------------------
    # LLM assistants
    # --------------------------------------------------------------------------
    # Enable the assistants and pre-populate the corp-domain noProxy list.
    # Whether the local mihomo proxy is wired (`proxy.enable = true`) is
    # left to the host leaf — the URL defaults to 127.0.0.1:7897, which is
    # mihomo, so flipping `proxy.enable` without `mihomo.enable` would
    # point assistants at a dead port.
    hakula.llm-assistants = {
      enable = lib.mkDefault true;
      proxy.noProxy = lib.mkDefault [
        "localhost"
        "127.0.0.1"
        "10.*"
        ".${corpDomain}"
      ];
    };

    # --------------------------------------------------------------------------
    # Mihomo (local proxy)
    # --------------------------------------------------------------------------
    # Off by default. Per-host opt-in: `hakula.mihomo.enable = true;` on the
    # leaf, paired with `hakula.llm-assistants.proxy.enable = true;`.
    hakula.mihomo = {
      enable = lib.mkDefault false;
      port = lib.mkDefault 7897;
      controllerPort = lib.mkDefault 59386;
    };

    # --------------------------------------------------------------------------
    # Secrets (work-flavor github PAT)
    # --------------------------------------------------------------------------
    # Override the logical `github-pat` secret to point at the work key.
    # `mkForce` because both this module and the per-host leaf may set it.
    hakula.secrets.required.github-pat.name = lib.mkForce "github/pat-work";

    # --------------------------------------------------------------------------
    # SSH (corp gitlab-public)
    # --------------------------------------------------------------------------
    programs.ssh.matchBlocks."gitlab-public.${corpDomain}" = {
      host = lib.mkDefault "gitlab-public.${corpDomain}";
      hostname = lib.mkDefault "gitlab-public.${corpDomain}";
      user = lib.mkDefault "git";
      port = lib.mkDefault 8022;
    };
  };
}
