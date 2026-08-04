# ==============================================================================
# Corporation Host Inventory
# ==============================================================================

let
  corpDomain = import ./corp-domain.nix;

  artifactory = "artifactory.${corpDomain}";
  githubMirror = "github-mirror.${corpDomain}";
  gitlab = "gitlab-space2.${corpDomain}";
  harbor = "harbor.${corpDomain}";
  llmGateway = "gw.llm.${corpDomain}";
  wiki = "wiki.${corpDomain}";
in
{
  inherit gitlab harbor llmGateway;

  wildcardDomain = ".${corpDomain}";

  artifactoryUrl = "https://${artifactory}/artifactory";
  githubMirrorUrl = "https://${githubMirror}";
  llmGatewayUrl = "https://${llmGateway}";
  wikiUrl = "https://${wiki}";
}
