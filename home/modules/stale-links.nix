# ==============================================================================
# Stale Link Pruning
# ==============================================================================

{
  lib,
  ...
}:

{
  # Home Manager's cleanup keeps paths present in both generations without
  # comparing types, stranding the old symlink when a managed leaf becomes a
  # directory. Linking then mkdir's through it into the read-only store.
  home.activation.pruneStaleLinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    homeFilePattern="$(readlink -e ${lib.escapeShellArg builtins.storeDir})/*-home-manager-files/*"
    newGenFiles="$(readlink -e "$newGenPath/home-files")"

    while IFS= read -r -d "" dir; do
      target="$HOME/''${dir#"$newGenFiles"/}"
      if [[ -L "$target" && "$(readlink "$target")" == $homeFilePattern ]]; then
        run rm $VERBOSE_ARG "$target"
      fi
    done < <(find "$newGenFiles" -mindepth 1 -type d -print0)
  '';
}
