# ==============================================================================
# Keka
# ==============================================================================

{
  config,
  ...
}:

let
  userName = config.hakula.user.name;
  homeDir = config.users.users.${userName}.home;
in
{
  homebrew.casks = [ "keka" ];

  system.defaults.CustomUserPreferences = {
    "${homeDir}/Library/Containers/com.aone.keka/Data/Library/Preferences/com.aone.keka" = {
      DefaultFormat = "XZ";
      DefaultMethod = 3;
      FinderAfterCompression = false;
      FinderAfterExtraction = false;
      SolidArchive = false;
      TarballSupport = true;
      UseDefaultPasswordOnAdvancedWindow = false;
      UseDefaultPasswordOnCompressions = false;
      UseDefaultPasswordOnExtractions = true;
    };
  };
}
