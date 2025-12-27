{ pkgs }:
{
  "clangd.path" = "${pkgs.llvmPackages.clang-tools}/bin/clangd";
  "nix.serverPath" = "${pkgs.nil}/bin/nil";
  "nix.serverSettings" = {
    nil = {
      formatting = {
        command = [ "${pkgs.nixfmt-rfc-style}/bin/nixfmt" ];
      };
    };
    nix = {
      binary = "${pkgs.nix}/bin/nix";
      flake = {
        autoArchive = true;
        autoEvalInputs = true;
      };
    };
  };
}
