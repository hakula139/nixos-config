# ==================================================================================================
# Keka (File Archiver)
# ==================================================================================================

{
  config,
  ...
}:

let
  userName = config.hakula.user.name;
  homeDir = config.users.users.${userName}.home;
in
{
  # ------------------------------------------------------------------------------------------------
  # Packages
  # ------------------------------------------------------------------------------------------------
  homebrew.casks = [ "keka" ];

  # ------------------------------------------------------------------------------------------------
  # Preferences
  # ------------------------------------------------------------------------------------------------
  system.defaults.CustomUserPreferences = {
    "${homeDir}/Library/Containers/com.aone.keka/Data/Library/Preferences/com.aone.keka" = {
      AlwaysAskCompressionPassword = false;
      DefaultFormat = "XZ";
      DefaultMethod = 3;
      ExcludeMacForks = true;
      ExtractOnIntermediateFolder = true;
      ExtractionExcludeMacForks = true;
      FinderAfterCompression = false;
      FinderAfterExtraction = false;
      ForceTarballOnCompressionOnly = true;
      SolidArchive = false;
      TarballSupport = true;
      UseDefaultPasswordOnAdvancedWindow = false;
      UseDefaultPasswordOnCompressions = false;
      UseDefaultPasswordOnExtractions = true;
    };
  };
}
