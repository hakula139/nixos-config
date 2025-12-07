{ pkgs, ... }:

{
  # ============================================================================
  # Core System Configuration
  # ============================================================================
  time.timeZone = "Asia/Shanghai";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [ "en_US.UTF-8/UTF-8" ];
    extraLocaleSettings = {
      LC_ALL = "en_US.UTF-8";
    };
  };

  # Console UTF-8 support
  console.keyMap = "us";

  # ============================================================================
  # Nix Settings
  # ============================================================================
  nix = {
    settings = {
      # Enable flakes and new nix command
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Avoid unwanted garbage collection when using nix-direnv
      keep-outputs = true;
      keep-derivations = true;
    };

    # Garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # ============================================================================
  # Networking
  # ============================================================================
  networking = {
    domain = "hakula.xyz";
    firewall.enable = true;
  };

  # ============================================================================
  # Users & Security
  # ============================================================================
  users.defaultUserShell = pkgs.zsh;

  users.users.hakula = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPqd9HS6uF0h0mXMbIwCv9yrkvvdl3o1wUgQWVkjKuiJ"
    ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPqd9HS6uF0h0mXMbIwCv9yrkvvdl3o1wUgQWVkjKuiJ"
  ];

  security.sudo.wheelNeedsPassword = false;

  # ============================================================================
  # Services
  # ============================================================================
  services.openssh = {
    enable = true;
    ports = [ 35060 ];
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # ============================================================================
  # Shell Configuration
  # ============================================================================
  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];

  # Environment variables for proper Unicode/icon rendering
  environment.variables = {
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
  };

  # ============================================================================
  # Fonts
  # Nerd Fonts provide icons for terminal tools like eza and starship
  # ============================================================================
  fonts = {
    packages = [
      pkgs.nerd-fonts.jetbrains-mono
    ];
    fontconfig.enable = true;
  };

  # ============================================================================
  # System Packages
  # ============================================================================
  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    vim

    # Nix tooling
    nil
    nixfmt-rfc-style
  ];

  # ============================================================================
  # Nix-LD
  # Enables running unpatched dynamically linked binaries
  # ============================================================================
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    curl
    glib
    glibc
    icu
    libkrb5
    libsecret
    libunwind
    libuuid
    openssl
    stdenv.cc.cc.lib
    util-linux
    zlib
  ];
}
