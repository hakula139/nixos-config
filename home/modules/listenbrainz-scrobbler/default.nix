# ==============================================================================
# ListenBrainz Scrobbler
# ==============================================================================

{
  config,
  lib,
  inputs,
  ...
}:

let
  cfg = config.hakula.listenbrainz-scrobbler;
in
{
  imports = [ inputs.listenbrainz-scrobbler.homeManagerModules.default ];

  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.listenbrainz-scrobbler = {
    enable = lib.mkEnableOption "Apple Music scrobbling to ListenBrainz";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    services.listenbrainz-scrobbler.enable = true;
  };
}
