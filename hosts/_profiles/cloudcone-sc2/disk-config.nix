{ ... }:

{
  # ============================================================================
  # CloudCone SC2 Disk Configuration
  # ============================================================================
  # NOTE: CloudCone's infrastructure has compatibility constraints:
  # 1. MBR (msdos) partition table. GPT is NOT supported by legacy bootloader.
  # 2. ext4 filesystem must disable newer features for backup system compatibility:
  #    - 64bit, metadata_csum: Legacy bootloader can't read these
  #    - orphan_file: CloudCone's backup system (old CentOS) lacks e2fsprogs 1.47+
  # ============================================================================
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/vda";
        content = {
          type = "table";
          format = "msdos";
          partitions = [
            {
              name = "root";
              start = "1M";
              end = "100%";
              bootable = true;
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                extraArgs = [
                  "-O"
                  "^64bit,^metadata_csum,^orphan_file"
                ];
              };
            }
          ];
        };
      };
    };
  };
}
