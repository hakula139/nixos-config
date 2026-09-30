# ==============================================================================
# Keka Archive Configuration
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
      DefaultFormat = "7Z";
      DefaultMethod = 3;
      FinderAfterCompression = false;
      FinderAfterExtraction = false;
      SolidArchive = false;
      UseDefaultPasswordOnAdvancedWindow = true;
      UseDefaultPasswordOnCompressions = true;
      UseDefaultPasswordOnExtractions = true;
    };
  };
}
