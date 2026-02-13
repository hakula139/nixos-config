{ lib }:

# ==============================================================================
# Shared Proxy Options
# ==============================================================================
# Reusable NixOS module option set for HTTP proxy configuration.
# Used by claude-code and codex Home Manager modules.

{
  mkProxyOptions = name: {
    enable = lib.mkEnableOption "HTTP proxy for ${name}";

    url = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:7897";
      description = "HTTP proxy URL for ${name}";
    };

    noProxy = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "localhost"
        "127.0.0.1"
      ];
      description = "Domains to bypass the proxy";
    };
  };
}
