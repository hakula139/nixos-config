# ==============================================================================
# Shared MCP Server Options
# ==============================================================================

{ lib }:

let
  serverDisplayNames = {
    braveSearch = "BraveSearch";
    codex = "Codex";
    context7 = "Context7";
    deepwiki = "DeepWiki";
    fetcher = "Fetcher";
    filesystem = "Filesystem";
    git = "Git";
    github = "GitHub";
    gitlab = "GitLab";
  };

  allServerNames = builtins.attrNames serverDisplayNames;
in
{
  inherit allServerNames serverDisplayNames;

  mkEnabledServersOption =
    {
      description,
      names ? allServerNames,
      default ? names,
    }:
    lib.mkOption {
      type = lib.types.listOf (lib.types.enum names);
      inherit default description;
    };

  mkDisabledServersOption =
    { description }:
    lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      inherit description;
    };
}
