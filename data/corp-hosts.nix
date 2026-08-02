# ==============================================================================
# Corporation Host Inventory
# ==============================================================================

let
  # Keep the placeholder in git. Override it locally, never commit the real value.
  corpDomain = "corp.example.com";
in
rec {
  wildcard = ".${corpDomain}";

  artifactory = "artifactory.${corpDomain}";
  githubMirror = "github-mirror.${corpDomain}";
  gitlab = "gitlab-space2.${corpDomain}";
  harbor = "harbor.${corpDomain}";
  llmGateway = "gw.llm.${corpDomain}";
  wiki = "wiki.${corpDomain}";

  artifactoryUrl = "https://${artifactory}/artifactory";
  githubMirrorUrl = "https://${githubMirror}";
  llmGatewayUrl = "https://${llmGateway}";
  wikiUrl = "https://${wiki}";
}
