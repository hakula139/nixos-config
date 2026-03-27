# ==============================================================================
# LLM Assistants
# ==============================================================================

{
  config,
  lib,
  ...
}:

let
  cfg = config.hakula.llm-assistants;
  proxyOptions = import ./shared/proxy.nix { inherit lib; };
in
{
  imports = [
    ./claude-code
    ./codex
    ./cursor
  ];

  options.hakula.llm-assistants = {
    enable = lib.mkEnableOption "LLM assistants defaults";
    proxy = proxyOptions.mkProxyOptions "LLM assistants";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        hakula.claude-code.enable = lib.mkDefault true;
        hakula.codex.enable = lib.mkDefault true;
      }

      (lib.mkIf cfg.proxy.enable {
        hakula.claude-code.proxy = {
          enable = lib.mkDefault true;
          url = lib.mkDefault cfg.proxy.url;
          noProxy = lib.mkDefault cfg.proxy.noProxy;
        };

        hakula.codex.proxy = {
          enable = lib.mkDefault true;
          url = lib.mkDefault cfg.proxy.url;
          noProxy = lib.mkDefault cfg.proxy.noProxy;
        };
      })
    ]
  );
}
