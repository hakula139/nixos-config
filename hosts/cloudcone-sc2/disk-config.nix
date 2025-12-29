{ ... }:

{
  # ============================================================================
  # CloudCone SC2 Disk Configuration
  # ============================================================================
  # NOTE: CloudCone's legacy bootloader requires:
  # 1. MBR (msdos) partition table. GPT is NOT supported.
  # 2. ext4 filesystem without '64bit' and 'metadata_csum' features.
  #    If enabled, the external bootloader cannot read the disk.
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
                  "^64bit,^metadata_csum"
                ];
              };
            }
          ];
        };
      };
    };
  };
}
