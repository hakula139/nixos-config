# ==================================================================================================
# Managed Hosts File Helpers
# ==================================================================================================

{
  mkNuCommand,
}:

{
  mkUpdateScript =
    {
      pkgs,
      name,
      owner,
      entries ? [ ],
      hostsFile ? "/etc/hosts",
      group ? "root",
    }:
    mkNuCommand {
      inherit pkgs name;
      script = ./update-hosts.nu;
      runtimeInputs = [
        pkgs.coreutils
      ];

      config = {
        inherit
          hostsFile
          owner
          entries
          group
          ;
      };
    };
}
