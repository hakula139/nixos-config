# ==================================================================================================
# LLM Assistant Source Control Scope
# ==================================================================================================

{
  corpHosts,
}:

let
  scopes = [
    "github.com/hakula139"
    corpHosts.gitlab
  ];
in
{
  ownRepositories = "repositories under ${builtins.concatStringsSep ", " scopes}";
}
