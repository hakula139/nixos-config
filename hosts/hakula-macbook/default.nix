{ ... }:

{
  imports = [
    ../../modules/darwin
  ];

  # ============================================================================
  # Credentials
  # ============================================================================
  hakula.cachix.enable = true;

  # ============================================================================
  # Primary User (required for user-specific system defaults)
  # ============================================================================
  system.primaryUser = "hakula";

  # ============================================================================
  # Host-Specific Configuration
  # ============================================================================
  networking.hostName = "Hakula-MacBook";

  # Computer name visible in Finder sidebar, AirDrop, etc.
  networking.computerName = "Hakula-MacBook";

  # Local hostname for Bonjour (hostname.local)
  networking.localHostName = "Hakula-MacBook";

  # ============================================================================
  # User Configuration
  # ============================================================================
  users.users.hakula = {
    name = "hakula";
    home = "/Users/hakula";
  };

  # ============================================================================
  # Host-Specific Packages
  # ============================================================================
  # environment.systemPackages = with pkgs; [ ];

  # ============================================================================
  # Host-Specific Homebrew
  # ============================================================================
  # homebrew.casks = [ ];
}
