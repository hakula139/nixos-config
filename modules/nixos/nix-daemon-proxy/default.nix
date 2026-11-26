# ==================================================================================================
# Nix Daemon Proxy
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  ...
}:

let
  cfg = config.hakula.nix-daemon.proxy;
  hasSecret = cfg.secretName != null;
  noProxy = repoLib.proxy.renderNoProxy cfg;

  proxyCfg = {
    inherit (cfg) enable url noProxy;
    secretUrlFile = if hasSecret then config.sops.secrets.nix-daemon-proxy-url.path else null;
  };

  nixCli = pkgs.runCommand "nix-proxy" { } ''
    install -d $out/bin
    ln -s ${
      repoLib.wrapPackage {
        inherit pkgs;
        pkg = pkgs.nix;
        wrapArgs = repoLib.proxy.mkProxyWrapArgs proxyCfg;
      }
    }/bin/nix $out/bin/nix
  '';
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.nix-daemon.proxy =
    removeAttrs (repoLib.proxy.mkProxyOptions "the Nix daemon") [ "secretUrlFile" ]
    // {
      secretName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "SOPS catalog name for the proxy URL. Overrides url when set.";
      };
    };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        environment.systemPackages = [ (lib.hiPrio nixCli) ];
      }

      (lib.mkIf hasSecret {
        sops.secrets.nix-daemon-proxy-url = repoLib.secrets.mkSecret {
          name = cfg.secretName;
          owner = config.hakula.user.name;
          inherit (config.hakula.user) group;
        };

        sops.templates."nix-daemon-proxy.env" = {
          restartUnits = [ "nix-daemon.service" ];
          content = ''
            HTTP_PROXY=${config.sops.placeholder.nix-daemon-proxy-url}
            http_proxy=${config.sops.placeholder.nix-daemon-proxy-url}
            HTTPS_PROXY=${config.sops.placeholder.nix-daemon-proxy-url}
            https_proxy=${config.sops.placeholder.nix-daemon-proxy-url}
            NO_PROXY=${noProxy}
            no_proxy=${noProxy}
          '';
        };

        systemd.services.nix-daemon.serviceConfig.EnvironmentFile =
          config.sops.templates."nix-daemon-proxy.env".path;
      })

      (lib.mkIf (!hasSecret) {
        systemd.services.nix-daemon.environment = {
          HTTP_PROXY = cfg.url;
          http_proxy = cfg.url;
          HTTPS_PROXY = cfg.url;
          https_proxy = cfg.url;
          NO_PROXY = noProxy;
          no_proxy = noProxy;
        };
      })
    ]
  );
}
