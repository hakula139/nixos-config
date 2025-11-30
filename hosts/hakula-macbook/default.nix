{ ... }:

{
  imports = [
    ../../modules/darwin.nix
  ];

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
  # environment.systemPackages = with pkgs; [
  # ];

  # ============================================================================
  # Host-Specific Homebrew
  # ============================================================================
  homebrew.casks = [
  ];
}
