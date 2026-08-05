# ==============================================================================
# Corporation Host Inventory
# ==============================================================================

let
  corpDomain = import ./corp-domain.nix;
in
rec {
  wildcardDomain = ".${corpDomain}";

  artifactory = "artifactory.${corpDomain}";
  githubMirror = "github-mirror.${corpDomain}";
  gitlab = "gitlab-space2.${corpDomain}";
  harbor = "harbor.${corpDomain}";
  llmGateway = "gw.llm.${corpDomain}";
  wiki = "wiki.${corpDomain}";

  artifactoryUrl = "https://${artifactory}/artifactory";
  githubMirrorUrl = "https://${githubMirror}";
  gitlabUrl = "https://${gitlab}";
  llmGatewayUrl = "https://${llmGateway}";
  wikiUrl = "https://${wiki}";
}
