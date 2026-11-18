# ==================================================================================================
# Companion Instruction Guides
# ==================================================================================================

{
  promptFragments,
}:

let
  inherit (promptFragments) readPrompt;
in
{
  "code-design.md" = readPrompt ./code-design.md;
  "delegation.md" = readPrompt ./delegation.md;
  "documentation.md" = readPrompt ./documentation.md;
  "editing-and-comments.md" = readPrompt ./editing-and-comments.md;
  "mcp-servers.md" = readPrompt ./mcp-servers.md;
  "terminals-and-workmux.md" = readPrompt ./terminals-and-workmux.md;
  "verification-and-tests.md" = readPrompt ./verification-and-tests.md;
  "writing.md" = readPrompt ./writing.md;
}
