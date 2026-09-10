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
  # Cursor's remote server starts with a clean environment and skips
  # zsh startup scripts, so prepend system-manager and Home Manager
  # paths here. Sourced before the server launches the extension host.
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
  '';
in
{
  ".cursor-server/data/Machine/settings.json".source = machineSettingsJson;
  ".cursor-server/server-env-setup".source = serverEnvSetup;
}
