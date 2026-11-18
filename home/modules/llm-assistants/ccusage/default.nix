# ==================================================================================================
# ccusage Configuration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  ...
}:

let
  json = pkgs.formats.json { };
in
lib.mkIf config.hakula.llm-assistants.enable {
  # ------------------------------------------------------------------------------------------------
  # Packages
  # ------------------------------------------------------------------------------------------------
  home.packages = [
    pkgs.ccusage
  ];

  # ------------------------------------------------------------------------------------------------
  # Configuration files
  # ------------------------------------------------------------------------------------------------
  # ccusage discovers configuration for all agents in the Claude directory.
  xdg.configFile."claude/ccusage.json".source = json.generate "ccusage.json" {
    pi.stores = [
      {
        name = "omp";
        path = "${config.lib.llmAssistants.configDirs.omp}/sessions";
      }
    ];
  };
}
