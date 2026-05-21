# ==============================================================================
# FHS Compatibility (Standard /usr/bin Layout)
# ==============================================================================

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.hakula.fhs-compat;

  shims = {
    # Coreutils
    cat = "${pkgs.coreutils}/bin/cat";
    chmod = "${pkgs.coreutils}/bin/chmod";
    chown = "${pkgs.coreutils}/bin/chown";
    cp = "${pkgs.coreutils}/bin/cp";
    env = "${pkgs.coreutils}/bin/env";
    head = "${pkgs.coreutils}/bin/head";
    ln = "${pkgs.coreutils}/bin/ln";
    ls = "${pkgs.coreutils}/bin/ls";
    mkdir = "${pkgs.coreutils}/bin/mkdir";
    mktemp = "${pkgs.coreutils}/bin/mktemp";
    mv = "${pkgs.coreutils}/bin/mv";
    rm = "${pkgs.coreutils}/bin/rm";
    sleep = "${pkgs.coreutils}/bin/sleep";
    tail = "${pkgs.coreutils}/bin/tail";
    uname = "${pkgs.coreutils}/bin/uname";

    # Archive / compression
    gunzip = "${pkgs.gzip}/bin/gunzip";
    gzip = "${pkgs.gzip}/bin/gzip";
    tar = "${pkgs.gnutar}/bin/tar";
    xz = "${pkgs.xz}/bin/xz";

    # Network
    curl = "${pkgs.curl}/bin/curl";
    wget = "${pkgs.wget}/bin/wget";

    # Text processing
    awk = "${pkgs.gawk}/bin/awk";
    grep = "${pkgs.gnugrep}/bin/grep";
    sed = "${pkgs.gnused}/bin/sed";

    # Filesystem & misc
    find = "${pkgs.findutils}/bin/find";
    which = "${pkgs.which}/bin/which";
    xargs = "${pkgs.findutils}/bin/xargs";
  };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.fhs-compat = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Populate /usr/bin with FHS-style shims for portable scripts.";
    };
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    system.activationScripts.fhsCompatShims.text = ''
      mkdir -p /usr/bin
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: target: "ln -sfn ${target} /usr/bin/${name}") shims
      )}
    '';
  };
}
