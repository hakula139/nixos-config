# ==============================================================================
# CloudCone SC2 Disk Configuration
# ==============================================================================

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/vda";
        content = {
          type = "table";
          # CloudCone's legacy bootloader cannot read GPT.
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
                # The backup image cannot read newer ext4 features.
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
