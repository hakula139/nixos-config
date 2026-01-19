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
    enable = true;

    settings = {
      devices = {
        "hakula-macbook" = {
          # cspell:disable-next-line
          id = "4K52NMQ-QSKVTWQ-CTJABEH-TSYH5MG-HS3FOKP-ETOLSWB-TC7PV6E-JR2KTAN";
        };
        "hakula-work" = {
          # cspell:disable-next-line
          id = "6MRKQMF-EG5RGDP-WEIJNSL-4U7DOC6-UH3WUUT-EPXFLUR-JGMIEWV-P6QIIAU";
        };
        "us-1" = {
          # cspell:disable-next-line
          id = "WMZORNC-QJTIIQX-4Y2OGVF-3O5IESF-3M3UGMN-HC2C7SG-S42OC47-JMCPFAK";
        };
        "us-2" = {
          # cspell:disable-next-line
          id = "VPCN2SN-IEOCBX2-5FXCNCD-4SRA7PO-SK34FRH-MJWCXXB-QCRGTJE-WFWXSAL";
        };
        "sg-1" = {
          # cspell:disable-next-line
          id = "TY4E6M5-W7CQMFI-XK3IPUV-RF35PE7-TXBAT23-H6AD3Y4-C6IDGDJ-JRXUDAS";
        };
      };

      folders = {
        "claude-code" = {
          path = claudeCodeSyncDir;
          devices = [
            "hakula-macbook"
            "hakula-work"
            "us-2"
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
