# ==============================================================================
# Cursor Remote Server
# ==============================================================================

{
  pkgs,
  lib,
  machineSettingsJson,
  systemManagerPaths,
}:

let
  # Cursor's remote server skips shell startup scripts, so set up its
  # environment here before it launches the extension host.
  serverEnvSetup = pkgs.writeText "cursor-server-env-setup" ''
    [ -r /etc/set-environment ] && . /etc/set-environment

    for p in ${
      lib.concatMapStringsSep " " (p: ''"${p}"'') (systemManagerPaths ++ [ "$HOME/.nix-profile/bin" ])
    }; do
      case ":$PATH:" in
        *":$p:"*) ;;
        *) [ -d "$p" ] && PATH="$p:$PATH" ;;
      esac
    done
    export PATH

    export TMUX_TMPDIR="''${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}"
  '';
in
{
  ".cursor-server/data/Machine/settings.json".source = machineSettingsJson;
  ".cursor-server/server-env-setup".source = serverEnvSetup;
}
