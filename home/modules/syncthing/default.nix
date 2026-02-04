{
  config,
  lib,
  ...
}:

# ==============================================================================
# Syncthing - Continuous File Synchronization
# Web UI: http://localhost:8384
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
    enable = lib.mkDefault true;

    settings = {
      devices = {
        "hakula-macbook" = {
          id = "4K52NMQ-QSKVTWQ-CTJABEH-TSYH5MG-HS3FOKP-ETOLSWB-TC7PV6E-JR2KTAN"; # cspell:disable-line
        };
        "hakula-work" = {
          id = "6MRKQMF-EG5RGDP-WEIJNSL-4U7DOC6-UH3WUUT-EPXFLUR-JGMIEWV-P6QIIAU"; # cspell:disable-line
        };
        "us-1" = {
          id = "WMZORNC-QJTIIQX-4Y2OGVF-3O5IESF-3M3UGMN-HC2C7SG-S42OC47-JMCPFAK"; # cspell:disable-line
        };
        "us-2" = {
          id = "XPM7UMK-GPINXXM-T3QXBDE-NVENU5C-OPPXPPM-7PNNJUC-RRI7HJE-2573IAM"; # cspell:disable-line
        };
        "us-3" = {
          id = "NOHM6HO-B7HDLSE-VRHSXU7-T6BF6JL-V522NLY-BMW3H5F-WYC72RD-A3HANAV"; # cspell:disable-line
        };
        "us-4" = {
          id = "B62RTKK-UFZ4SZZ-BV2LPT7-LXVUU64-TJITT2X-NTZBYUH-VQYM2SN-J3OFBA6"; # cspell:disable-line
        };
        "sg-1" = {
          id = "TY4E6M5-W7CQMFI-XK3IPUV-RF35PE7-TXBAT23-H6AD3Y4-C6IDGDJ-JRXUDAS"; # cspell:disable-line
          ignoredFolders = [
            { id = "claude-code"; }
          ];
        };
      };

      folders = {
        "claude-code" = {
          path = claudeCodeSyncDir;
          devices = [
            "hakula-macbook"
            "hakula-work"
            "us-1"
            "us-2"
            "us-3"
            "us-4"
          ];
          ignorePerms = false;
        };
      };
    };

    overrideDevices = true;
    overrideFolders = true;
  };

  home.activation.syncthingSymlinks = lib.mkIf config.hakula.claude-code.enable (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      install -d -m 0700 "${claudeCodeSyncDir}"

      for file in ${builtins.toString claudeCodeFiles}; do
        if [[ ! -e "${homeDir}/$file" ]]; then
          mkdir -p "$(dirname "${claudeCodeSyncDir}/$file")"
          mkdir -p "$(dirname "${homeDir}/$file")"
          ln -sfn "${claudeCodeSyncDir}/$file" "${homeDir}/$file"
        fi
      done
    ''
  );
}
