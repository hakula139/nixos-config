# ==================================================================================================
# Nix Configuration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  repoLib,
  enableDevToolchains,
  secretPath,
  ...
}:

let
  cfg = config.hakula.nix;

  accessTokensFile = "${config.xdg.configHome}/nix/access-tokens.conf";

  activateAccessTokens = repoLib.mkNuCommand {
    inherit pkgs;
    name = "nix-activate-access-tokens";
    script = ./activate-access-tokens.nu;
    runtimeInputs = [ pkgs.coreutils ];
    flags = {
      token-file = secretPath "github/pat";
      output-file = accessTokensFile;
    };
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.nix.configPath = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Absolute path to the local nixos-config checkout";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkMerge [
    # ----------------------------------------------------------------------------------------------
    # Nix Registry
    # ----------------------------------------------------------------------------------------------
    # Home Manager's `flake` option also copies `revCount`, which only a full clone reports, so a
    # local checkout would evaluate to different derivations than CI and miss its binary cache.
    {
      nix.registry.nixos-config.to = {
        type = "path";
        path = inputs.self.outPath;
      }
      // lib.filterAttrs (
        name: _:
        lib.elem name [
          "lastModified"
          "narHash"
          "rev"
        ]
      ) inputs.self;
    }

    # ----------------------------------------------------------------------------------------------
    # Repository Path
    # ----------------------------------------------------------------------------------------------
    (lib.mkIf (cfg.configPath != null) {
      xdg.configFile."nixos-config/repository".text = cfg.configPath + "\n";
    })

    # ----------------------------------------------------------------------------------------------
    # GitHub Access Token
    # ----------------------------------------------------------------------------------------------
    # An access token switches `github:` fetches to `api.github.com` and `codeload.github.com`,
    # raising the rate limit to 5,000/hr and working through the corporate proxy on devvm.
    (lib.mkIf enableDevToolchains {
      hakula.secrets.required."github/pat" = { };

      nix.extraOptions = "!include ${accessTokensFile}";

      home.activation.nixAccessTokens = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe activateAccessTokens}
      '';
    })
  ];
}
