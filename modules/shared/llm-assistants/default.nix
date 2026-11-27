# ==================================================================================================
# LLM Assistants Integration
# ==================================================================================================

{
  config,
  lib,
  ...
}:

let
  cfg = config.hakula.llm-assistants;
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.llm-assistants = {
    enable = lib.mkEnableOption "LLM assistants for the primary interactive user";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    home-manager.users.${config.hakula.user.name}.hakula.llm-assistants.enable = lib.mkDefault true;
  };
}
