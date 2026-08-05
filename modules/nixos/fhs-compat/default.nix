# ==============================================================================
# FHS Compatibility (Standard /bin and /usr/bin Layout)
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
    basename = "${pkgs.coreutils}/bin/basename";
    cat = "${pkgs.coreutils}/bin/cat";
    chmod = "${pkgs.coreutils}/bin/chmod";
    chown = "${pkgs.coreutils}/bin/chown";
    cp = "${pkgs.coreutils}/bin/cp";
    cut = "${pkgs.coreutils}/bin/cut";
    date = "${pkgs.coreutils}/bin/date";
    dirname = "${pkgs.coreutils}/bin/dirname";
    echo = "${pkgs.coreutils}/bin/echo";
    env = "${pkgs.coreutils}/bin/env";
    head = "${pkgs.coreutils}/bin/head";
    ln = "${pkgs.coreutils}/bin/ln";
    ls = "${pkgs.coreutils}/bin/ls";
    mkdir = "${pkgs.coreutils}/bin/mkdir";
    mktemp = "${pkgs.coreutils}/bin/mktemp";
    mv = "${pkgs.coreutils}/bin/mv";
    printf = "${pkgs.coreutils}/bin/printf";
    pwd = "${pkgs.coreutils}/bin/pwd";
    readlink = "${pkgs.coreutils}/bin/readlink";
    realpath = "${pkgs.coreutils}/bin/realpath";
    rm = "${pkgs.coreutils}/bin/rm";
    sleep = "${pkgs.coreutils}/bin/sleep";
    sort = "${pkgs.coreutils}/bin/sort";
    stat = "${pkgs.coreutils}/bin/stat";
    tail = "${pkgs.coreutils}/bin/tail";
    tee = "${pkgs.coreutils}/bin/tee";
    touch = "${pkgs.coreutils}/bin/touch";
    tr = "${pkgs.coreutils}/bin/tr";
    uname = "${pkgs.coreutils}/bin/uname";
    wc = "${pkgs.coreutils}/bin/wc";

    # Archive / compression
    gunzip = "${pkgs.gzip}/bin/gunzip";
    gzip = "${pkgs.gzip}/bin/gzip";
    tar = "${pkgs.gnutar}/bin/tar";
    xz = "${pkgs.xz}/bin/xz";

    # Network
    curl = "${pkgs.curl}/bin/curl";
    wget = "${pkgs.wget}/bin/wget";

    # Process management
    ps = "${pkgs.procps}/bin/ps";

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
      description = "Populate /bin and /usr/bin with FHS-style shims for portable scripts.";
    };
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    system.activationScripts.fhsCompatShims.text = ''
      mkdir -p /bin /usr/bin
      ln -sfn ${pkgs.bash}/bin/bash /bin/bash
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: target: "ln -sfn ${target} /usr/bin/${name}") shims
      )}
    '';
  };
}
