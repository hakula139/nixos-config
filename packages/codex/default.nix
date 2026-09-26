# ==============================================================================
# Codex CLI Package
# ==============================================================================

{
  pkgs,
  lib,
  upstream,
}:

let
  upstreamBin =
    if pkgs.stdenv.hostPlatform.isLinux then "${upstream}/libexec/codex/bin" else "${upstream}/bin";
  manifest = pkgs.writeText "codex-package.json" (
    builtins.toJSON {
      layoutVersion = 1;
      # Build metadata prevents the daemon from updating outside Nix.
      version = "${upstream.version}+nix";
      target = pkgs.stdenv.hostPlatform.rust.rustcTarget;
      entrypoint = "bin/codex";
    }
  );
in
# The daemon copies package files and rejects links outside the package root.
pkgs.runCommand "codex-${upstream.version}"
  {
    inherit (upstream)
      meta
      passthru
      src
      version
      ;
    pname = "codex";
  }
  ''
    set -euo pipefail

    mkdir -p "$out/bin" "$out/codex-path"
    install -m 755 ${upstreamBin}/codex "$out/bin/codex"
    install -m 755 ${upstreamBin}/codex-code-mode-host "$out/bin/codex-code-mode-host"
    install -m 755 ${upstreamBin}/logs_client "$out/bin/logs_client"
    install -m 755 ${lib.getExe pkgs.ripgrep} "$out/codex-path/rg"
    install -m 644 ${manifest} "$out/codex-package.json"
    cp -R ${upstream}/share "$out/share"

    ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
      mkdir -p "$out/codex-resources"
      install -m 755 ${lib.getExe pkgs.bubblewrap} "$out/codex-resources/bwrap"
    ''}
  ''
