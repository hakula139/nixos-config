# ==============================================================================
# WSL Workstation Bundle
# ==============================================================================
# Shared Home Manager bundle for WSL workstation hosts. Mihomo and the
# local proxy stay defined but disabled, since their URLs default to
# 127.0.0.1:7897 and a host without subscription secrets would dial a
# dead port. Each host enables them as a pair when ready.
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
    # Plain assignment: the system-side claude-code module already
    # propagates `defaultProfile` with `mkDefault`, so wrapping ours
    # would tie at priority 1000 and trip a merge error.
    hakula.claude-code.auth = {
      defaultProfile = "corp-gateway";
      enableCorpGateway = true;
    };

    # --------------------------------------------------------------------------
    # Cursor
    # --------------------------------------------------------------------------
    # Keep marketplace extensions installed outside Nix (e.g. corp-internal
    # ones) across `nixsw` runs.
    hakula.cursor.extensions.prune = lib.mkDefault false;

    hakula.fonts.windowsSync.enable = lib.mkDefault true;

    # --------------------------------------------------------------------------
    # LLM assistants
    # --------------------------------------------------------------------------
    # Whether to wire the local proxy is left to the host leaf, since the
    # URL defaults to mihomo at 127.0.0.1:7897 and pairing matters.
    hakula.llm-assistants = {
      enable = lib.mkDefault true;
      proxy.noProxy = lib.mkDefault [
        "localhost"
        "127.0.0.1"
        "10.*"
        ".${corpDomain}"
      ];
    };

    hakula.mihomo = {
      enable = lib.mkDefault false;
      port = lib.mkDefault 7897;
      controllerPort = lib.mkDefault 59386;
    };

    # --------------------------------------------------------------------------
    # Secrets (work-flavor github PAT)
    # --------------------------------------------------------------------------
    # `mkForce` because both this bundle and per-host leaves may set the
    # logical `github-pat` key.
    hakula.secrets.required.github-pat.name = lib.mkForce "github/pat-work";

    programs.ssh.matchBlocks."gitlab-public.${corpDomain}" = {
      host = lib.mkDefault "gitlab-public.${corpDomain}";
      hostname = lib.mkDefault "gitlab-public.${corpDomain}";
      user = lib.mkDefault "git";
      port = lib.mkDefault 8022;
    };
  };
}
