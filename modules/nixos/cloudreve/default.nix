{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Cloudreve (Self-hosted Cloud Storage)
# ==============================================================================

let
  cfg = config.hakula.services.cloudreve;

  serviceUser = "cloudreve";
  serviceGroup = "cloudreve";

  stateDirName = "cloudreve";

  dbName = "cloudreve";
  dbUser = "cloudreve";
  dbSocketDir = "/run/postgresql";

  redisInstance = "cloudreve";
  redisSocket = "/run/redis-cloudreve/redis.sock";
  redisGroup = "redis-${redisInstance}";

  cloudreve = pkgs.stdenv.mkDerivation rec {
    pname = "cloudreve";
    version = "4.10.1";

    src = pkgs.fetchurl {
      url = "https://github.com/cloudreve/cloudreve/releases/download/${version}/cloudreve_${version}_linux_amd64.tar.gz";
      hash = "sha256-tNZg+ocgr65vyBkRDQhyX0DmLQuO0JwbXUzTeL4hSAc=";
    };

    sourceRoot = ".";

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];

    installPhase = ''
      runHook preInstall
      install -Dm755 cloudreve $out/bin/cloudreve
      runHook postInstall
    '';

    meta = {
      description = "Self-hosted file management and sharing system";
      homepage = "https://cloudreve.org";
      license = lib.licenses.gpl3Plus;
      platforms = [ "x86_64-linux" ];
      mainProgram = "cloudreve";
    };
  };

  cloudreveConfTemplate = pkgs.writeText "cloudreve-conf.ini" ''
    [System]
    Mode = master
    Listen = :${toString cfg.port}

    [Database]
    Type = postgres
    Host = ${dbSocketDir}
    Port = 5432
    User = ${dbUser}
    Name = ${dbName}
    UnixSocket = true

    [Redis]
    Network = unix
    Server = ${redisSocket}
    DB = 0
  '';
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.cloudreve = {
    enable = lib.mkEnableOption "Cloudreve cloud storage service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5212;
      description = "Port for Cloudreve web interface";
    };
  };

  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------
    # Users & Groups
    # ----------------------------------------------------------------------------
    users.users.${serviceUser} = {
      isSystemUser = true;
      group = serviceGroup;
      extraGroups = [ redisGroup ];
      home = "/var/lib/${stateDirName}";
      createHome = false;
    };
    users.groups.${serviceGroup} = { };

    # ----------------------------------------------------------------------------
    # PostgreSQL (local)
    # ----------------------------------------------------------------------------
    services.postgresql = {
      enable = true;
      enableTCPIP = false;
      ensureDatabases = [ dbName ];
      ensureUsers = [
        {
          name = dbUser;
          ensureDBOwnership = true;
        }
      ];
      authentication = lib.mkForce ''
        local all postgres peer
        local ${dbName} ${dbUser} peer
        local all all reject
      '';
    };

    # ----------------------------------------------------------------------------
    # Redis (local)
    # ----------------------------------------------------------------------------
    services.redis.servers.${redisInstance} = {
      enable = true;
      port = 0;
      unixSocket = redisSocket;
      unixSocketPerm = 660;
    };

    # ----------------------------------------------------------------------------
    # Cloudreve systemd service
    # ----------------------------------------------------------------------------
    systemd.services.cloudreve = {
      description = "Cloudreve file management and sharing system";
      documentation = [ "https://docs.cloudreve.org" ];

      after = [
        "network.target"
        "postgresql.service"
        "redis-${redisInstance}.service"
      ];
      requires = [
        "postgresql.service"
        "redis-${redisInstance}.service"
      ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        install -m 0755 ${lib.getExe cloudreve} "$STATE_DIRECTORY/cloudreve"
        install -d -m 0750 "$STATE_DIRECTORY/data"
        if [ ! -f "$STATE_DIRECTORY/data/conf.ini" ]; then
          install -m 0600 ${cloudreveConfTemplate} "$STATE_DIRECTORY/data/conf.ini"
        fi
      '';

      serviceConfig = {
        Type = "simple";
        ExecStart = "%S/${stateDirName}/cloudreve";
        Restart = "on-failure";
        RestartSec = "5s";
        User = serviceUser;
        Group = serviceGroup;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        StateDirectory = stateDirName;
        StateDirectoryMode = "0750";
        UMask = "0077";
        WorkingDirectory = "%S/${stateDirName}";
        ReadWritePaths = [ "%S/${stateDirName}" ];
      };
    };
  };
}
