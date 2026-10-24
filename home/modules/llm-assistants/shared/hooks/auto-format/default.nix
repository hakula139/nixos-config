# ==================================================================================================
# Auto-Format Hook
# ==================================================================================================

{
  pkgs,
  lib,
  enableDevToolchains,
  mkNuHook,
  patchInput,
  repo,
  timeouts,
}:

let
  # An empty tool path keeps that package out of a non-dev host's closure.
  whenDev = pkg: if enableDevToolchains then lib.getExe pkg else "";
  whenDevPath = path: if enableDevToolchains then "${path}" else "";

  markdownlintConfig = lib.path.append repo.root ".markdownlint.jsonc";

  dprintConfig = import ./dprint.nix { inherit pkgs; };
in
{
  event = "PostToolUse";
  type = "command";
  tools = [ "fileWrite" ];
  timeout = timeouts.postEdit;
  statusMessage = "Formatting edited files";
  command = mkNuHook {
    slug = "auto-format";
    script = ./auto-format.nu;
    config = {
      cspell = whenDev pkgs.cspell;
      direnv = whenDev pkgs.direnv;
      dprint = whenDev pkgs.dprint;
      dprintConfig = whenDevPath dprintConfig;
      git = lib.getExe pkgs.git;
      markdownlint = whenDev pkgs.markdownlint-cli2;
      markdownlintConfig = whenDevPath markdownlintConfig;
      nixfmt = lib.getExe pkgs.nixfmt;
      nuCheck = "${pkgs.nu-check}";
      patchInput = toString patchInput;
      prettier = whenDev pkgs.unstable.prettier;
      pyright = whenDev pkgs.pyright;
      ruff = whenDev pkgs.ruff;
      shellcheck = lib.getExe pkgs.shellcheck;
      shfmt = lib.getExe pkgs.shfmt;
      taplo = whenDev pkgs.taplo;
    };
  };
}
