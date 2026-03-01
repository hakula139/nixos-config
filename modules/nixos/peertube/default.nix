{
  config,
  pkgs,
  lib,
  secrets,
  ...
}:

# ==============================================================================
# PeerTube (Video Streaming Platform)
# ==============================================================================

let
  cfg = config.hakula.services.peertube;

  domain = "v.hakula.xyz";
  endpoint = "s3.us-west-004.backblazeb2.com";
  cdnBaseUrl = "https://b2.hakula.xyz";

  mkBucket = suffix: {
    bucket_name = cfg.b2Bucket;
    base_url = cdnBaseUrl;
    prefix =
      (lib.concatStringsSep "/" (
        lib.filter (p: p != "") [
          cfg.b2Path
          suffix
        ]
      ))
      + "/";
  };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.peertube = {
    enable = lib.mkEnableOption "PeerTube video streaming platform";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9000;
      description = "Port for PeerTube web interface";
    };

    b2Bucket = lib.mkOption {
      type = lib.types.str;
      example = "hakula";
      description = "Backblaze B2 bucket name for video storage";
    };

    b2Path = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "peertube";
      description = "Base path within the B2 bucket for video storage";
    };
  };

  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets.peertube-env = secrets.mkSecret {
      name = "peertube-env";
      owner = "peertube";
      group = "peertube";
    };

    age.secrets.peertube-secret = secrets.mkSecret {
      name = "peertube-secret";
      owner = "peertube";
      group = "peertube";
    };

    # --------------------------------------------------------------------------
    # Service
    # --------------------------------------------------------------------------
    services.peertube = {
      enable = true;
      package = pkgs.unstable.peertube;

      localDomain = domain;
      listenHttp = cfg.port;
      listenWeb = 443;
      enableWebHttps = true;
      configureNginx = false; # handled by our nginx module

      database.createLocally = true;
      redis.createLocally = true;

      secrets.secretsFile = config.age.secrets.peertube-secret.path;
      serviceEnvironmentFile = config.age.secrets.peertube-env.path;

      settings = {
        object_storage = {
          enabled = true;
          inherit endpoint;
          # B2 uses path-style S3 URLs; required for CDN base_url to include bucket in path
          force_path_style = true;
          # B2 doesn't support ACL headers; bucket is private, served via Cloudflare Worker CDN
          upload_acl = {
            public = null;
            private = null;
          };
          original_video_files = mkBucket "original-video-files";
          web_videos = mkBucket "web-videos";
          streaming_playlists = mkBucket "streaming-playlists";
        };

        # Offloaded to MacBook via remote runner:
        #
        #   ssh -L 9000:127.0.0.1:9000 CloudCone-US-1 -N
        #   peertube-runner server
        #   peertube-runner register \
        #     --url http://localhost:9000 \
        #     --registration-token <token> \
        #     --runner-name macbook
        transcoding = {
          enabled = true;
          remote_runners.enabled = true;
        };

        http_timeouts.request = "30 minutes";
      };
    };
  };
}
