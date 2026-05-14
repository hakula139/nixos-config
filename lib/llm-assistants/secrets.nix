{
  secrets,
  homeDir,
}:

let
  secretsDir = secrets.secretsPath homeDir;
in
{
  mcp = {
    brave-api-key = {
      name = "llm-assistants/mcp/brave-api-key";
      path = "${secretsDir}/llm-assistants/mcp/brave-api-key";
    };

    confluence-pat = {
      name = "llm-assistants/mcp/confluence-pat";
      path = "${secretsDir}/llm-assistants/mcp/confluence-pat";
    };

    context7-api-key = {
      name = "llm-assistants/mcp/context7-api-key";
      path = "${secretsDir}/llm-assistants/mcp/context7-api-key";
    };

    github-pat = {
      name = "github/pat-personal";
      path = "${secretsDir}/github/pat";
    };
  };
}
