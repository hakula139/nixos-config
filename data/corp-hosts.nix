# ==================================================================================================
# Corporation Host Inventory
# ==================================================================================================

rec {
  domain = import ./corp-domain.nix;
  wildcardDomain = ".${domain}";

  artifactory = "artifactory.${domain}";
  githubMirror = "github-mirror.${domain}";
  gitlab = "gitlab-space2.${domain}";
  harbor = "harbor.${domain}";
  llmGateway = "gw.llm.${domain}";
  mirrorCatalog = "mirror-catalog.${domain}";
  wiki = "wiki.${domain}";

  artifactoryUrl = "https://${artifactory}/artifactory";
  githubMirrorUrl = "https://${githubMirror}";
  gitlabUrl = "https://${gitlab}";
  llmGatewayUrl = "https://${llmGateway}";
  mirrorCatalogUrl = "https://${mirrorCatalog}";
  wikiUrl = "https://${wiki}";
}
