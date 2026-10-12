# ==================================================================================================
# Syncthing - Continuous File Synchronization
# Web UI: http://localhost:8384
# ==================================================================================================

{
  config,
  lib,
  hostType,
  ...
}:

let
  cfg = config.hakula.syncthing;

  homeDir = config.home.homeDirectory;
  syncDir = "${homeDir}/synced";

  syncDevices = {
    "hakula-macbook" = {
      id = "4K52NMQ-QSKVTWQ-CTJABEH-TSYH5MG-HS3FOKP-ETOLSWB-TC7PV6E-JR2KTAN"; # cspell:disable-line
    };
    "us-1" = {
      id = "WMZORNC-QJTIIQX-4Y2OGVF-3O5IESF-3M3UGMN-HC2C7SG-S42OC47-JMCPFAK"; # cspell:disable-line
    };
    "us-4" = {
      id = "B62RTKK-UFZ4SZZ-BV2LPT7-LXVUU64-TJITT2X-NTZBYUH-VQYM2SN-J3OFBA6"; # cspell:disable-line
    };
  };

  syncedFolders = {
    claude-code = {
      enable = config.hakula.claude-code.enable;
      files = [
        ".claude.json"
        ".claude/.credentials.json"
      ];
    };

    codex = {
      enable = config.hakula.codex.enable;
      files = [
        ".codex/auth.json"
      ];
    };
  };

  linkedFolders = lib.filterAttrs (_: folder: folder.enable) syncedFolders;

  mkVersionedFolder = id: _: {
    path = "${syncDir}/${id}";
    devices = builtins.attrNames syncDevices;
    ignorePerms = false;
    versioning = {
      type = "staggered";
      params = {
        cleanInterval = "3600";
        maxAge = "604800"; # 7 days
      };
    };
  };

  mkSymlinks =
    id:
    { files, ... }:
    let
      folderDir = "${syncDir}/${id}";
    in
    ''
      run install -d -m 0700 "${folderDir}"

      for file in ${toString files}; do
        if [[ ! -e "${homeDir}/$file" ]]; then
          run mkdir -p "$(dirname "${folderDir}/$file")"
          run mkdir -p "$(dirname "${homeDir}/$file")"
          run ln -sfn "${folderDir}/$file" "${homeDir}/$file"
        fi
      done
    '';
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.syncthing = {
    enable = lib.mkEnableOption "Syncthing sync of personal assistant credentials";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkMerge [
    {
      hakula.syncthing.enable = lib.mkDefault (hostType == "personal");
    }

    (lib.mkIf cfg.enable {
      services.syncthing = {
        enable = true;

        settings = {
          devices = syncDevices;
          folders = lib.mapAttrs mkVersionedFolder syncedFolders;
        };

        overrideDevices = true;
        overrideFolders = true;
      };

      home.activation.syncthingSymlinks = lib.mkIf (linkedFolders != { }) (
        lib.hm.dag.entryAfter [ "writeBoundary" ] (
          lib.concatStrings (lib.mapAttrsToList mkSymlinks linkedFolders)
        )
      );
    })
  ];
}
