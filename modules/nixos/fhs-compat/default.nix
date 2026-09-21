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
    basename = lib.getExe' pkgs.coreutils "basename";
    cat = lib.getExe' pkgs.coreutils "cat";
    chmod = lib.getExe' pkgs.coreutils "chmod";
    chown = lib.getExe' pkgs.coreutils "chown";
    cp = lib.getExe' pkgs.coreutils "cp";
    cut = lib.getExe' pkgs.coreutils "cut";
    date = lib.getExe' pkgs.coreutils "date";
    dirname = lib.getExe' pkgs.coreutils "dirname";
    echo = lib.getExe' pkgs.coreutils "echo";
    env = lib.getExe' pkgs.coreutils "env";
    head = lib.getExe' pkgs.coreutils "head";
    ln = lib.getExe' pkgs.coreutils "ln";
    ls = lib.getExe' pkgs.coreutils "ls";
    mkdir = lib.getExe' pkgs.coreutils "mkdir";
    mktemp = lib.getExe' pkgs.coreutils "mktemp";
    mv = lib.getExe' pkgs.coreutils "mv";
    printf = lib.getExe' pkgs.coreutils "printf";
    pwd = lib.getExe' pkgs.coreutils "pwd";
    readlink = lib.getExe' pkgs.coreutils "readlink";
    realpath = lib.getExe' pkgs.coreutils "realpath";
    rm = lib.getExe' pkgs.coreutils "rm";
    sleep = lib.getExe' pkgs.coreutils "sleep";
    sort = lib.getExe' pkgs.coreutils "sort";
    stat = lib.getExe' pkgs.coreutils "stat";
    tail = lib.getExe' pkgs.coreutils "tail";
    tee = lib.getExe' pkgs.coreutils "tee";
    touch = lib.getExe' pkgs.coreutils "touch";
    tr = lib.getExe' pkgs.coreutils "tr";
    uname = lib.getExe' pkgs.coreutils "uname";
    wc = lib.getExe' pkgs.coreutils "wc";

    # Archive / compression
    gunzip = lib.getExe' pkgs.gzip "gunzip";
    gzip = lib.getExe pkgs.gzip;
    tar = lib.getExe pkgs.gnutar;
    xz = lib.getExe' pkgs.xz "xz";

    # Network
    curl = lib.getExe pkgs.curl;
    wget = lib.getExe pkgs.wget;

    # Process management
    ps = lib.getExe' pkgs.procps "ps";

    # Text processing
    awk = lib.getExe' pkgs.gawk "awk";
    grep = lib.getExe pkgs.gnugrep;
    sed = lib.getExe pkgs.gnused;

    # Filesystem & misc
    find = lib.getExe pkgs.findutils;
    which = lib.getExe pkgs.which;
    xargs = lib.getExe' pkgs.findutils "xargs";
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
      ln -sfn ${lib.getExe pkgs.bash} /bin/bash
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: target: "ln -sfn ${target} /usr/bin/${name}") shims
      )}
    '';
  };
}
