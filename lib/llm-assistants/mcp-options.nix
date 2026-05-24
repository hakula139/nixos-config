# ==============================================================================
# MCP Server Options
# ==============================================================================

{ lib }:

let
  serverDisplayNames = {
    atlassian = "Atlassian";
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

  commonServerNames = [
    "atlassian"
    "braveSearch"
    "deepwiki"
    "fetcher"
    "filesystem"
    "git"
    "github"
    "gitlab"
  ];

  corpServerNames = [
    "atlassian"
    "gitlab"
  ];

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

  mkMcpOptions =
    {
      names,
      description ? "MCP servers",
    }:
    {
      enabledServers = mkEnabledServersOption {
        inherit names;
        description = "${description} to enable";
      };
      disabledServers = mkDisabledServersOption {
        description = "${description} to disable";
      };
    };

  computeEnabledServers = cfg: lib.subtractLists cfg.disabledServers cfg.enabledServers;
in
{
  inherit
    allServerNames
    commonServerNames
    corpServerNames
    serverDisplayNames
    mkEnabledServersOption
    mkDisabledServersOption
    mkMcpOptions
    computeEnabledServers
    ;
}
