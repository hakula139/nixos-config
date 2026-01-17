{
  config,
  lib,
  ...
}:

# ==============================================================================
# Syncthing - Continuous File Synchronization
# ==============================================================================

let
  homeDir = config.home.homeDirectory;
  syncDir = "${homeDir}/synced";

  claudeCodeSyncDir = "${syncDir}/claude-code";
  claudeCodeFiles = [
    ".claude.json"
    ".claude/.credentials.json"
  ];
in
{
  services.syncthing = {
    enable = true;

    settings = {
      devices = {
        "hakula-macbook" = {
          id = "K5RNBD3-2UASGL4-G4DJJEG-35NPPQK-LRB5KLH-6PF4NKZ-CF7MW37-2SDVWQS";
        };
      };

      folders = {
        "claude-code" = {
          path = claudeCodeSyncDir;
          devices = [
            "hakula-macbook"
          ];
          ignorePerms = false;
        };
      };
    };

    overrideDevices = true;
    overrideFolders = true;
  };

  home.activation.syncthingSymlinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    install -d -m 0700 "${claudeCodeSyncDir}"

    for file in ${builtins.toString claudeCodeFiles}; do
      if [[ ! -e "${homeDir}/$file" ]]; then
        mkdir -p "$(dirname "${claudeCodeSyncDir}/$file")"
        mkdir -p "$(dirname "${homeDir}/$file")"
        ln -sfn "${claudeCodeSyncDir}/$file" "${homeDir}/$file"
      fi
    done
  '';
}
