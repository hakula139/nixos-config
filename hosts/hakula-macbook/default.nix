{ ... }:

{
  imports = [
    ../../modules/darwin
  ];

  # ============================================================================
  # Primary User (required for user-specific system defaults)
  # ============================================================================
  system.primaryUser = "hakula";

  # ============================================================================
  # Secrets (agenix)
  # ============================================================================
  age.secrets.brave-api-key = {
    file = ../../secrets/shared/brave-api-key.age;
    owner = "hakula";
  };

  age.secrets.context7-api-key = {
    file = ../../secrets/shared/context7-api-key.age;
    owner = "hakula";
  };

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
