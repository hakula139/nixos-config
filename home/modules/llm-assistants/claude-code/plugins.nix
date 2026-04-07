# ==============================================================================
# Claude Code Plugins
# ==============================================================================

{
  pkgs,
  lib,
  devToolchains ? false,
  online ? true,
}:

let
  json = pkgs.formats.json { };

  # ----------------------------------------------------------------------------
  # Marketplace Definitions
  # ----------------------------------------------------------------------------
  marketplaces = {
    anthropic-agent-skills = {
      github = {
        owner = "anthropics";
        repo = "skills";
      };
      rev = "98669c11ca63e9c81c11501e1437e5c47b556621";
      hash = "sha256-w//9LB1OVG9jlllY+VDse7Js0dn5x6Ys2vPuQACKsTM=";
      pluginsDir = null;
    };

    claude-plugins-official = {
      github = {
        owner = "anthropics";
        repo = "claude-plugins-official";
      };
      rev = "183a6ca35d5f6b4ba99bf89777bd0aa432fa3d2e";
      hash = "sha256-IUrfycw/bzuuuTTYNZGWnOE5vSygGa+ORCqbEo6/J0k=";
      pluginsDir = "plugins";
    };

    agent-browser = {
      github = {
        owner = "vercel-labs";
        repo = "agent-browser";
      };
      rev = "312db04e5e2e68a9c1725548b12352d0a55e84db";
      hash = "sha256-E6IHEyd5voAyNXQyl4bCvyfeZQaSoztplXlKe449EEI=";
      pluginsDir = null;
    };

    context7-marketplace = {
      github = {
        owner = "upstash";
        repo = "context7";
      };
      rev = "658ec6796ec2085e6a24bdab842b6949e4aa2fe8";
      hash = "sha256-+OGk7PHZyb8Cny8nM2p3+4IBSQeVf6MXO2G/UFyEugc=";
      pluginsDir = null;
    };
  };

  # ----------------------------------------------------------------------------
  # Enabled Plugins
  # ----------------------------------------------------------------------------
  enabledPlugins = {
    # Official skills
    "claude-api@anthropic-agent-skills" = true;
    "document-skills@anthropic-agent-skills" = true;

    # Official plugins
    "claude-code-setup@claude-plugins-official" = true;
    "claude-md-management@claude-plugins-official" = true;
    "code-review@claude-plugins-official" = true;
    "commit-commands@claude-plugins-official" = true;
    "explanatory-output-style@claude-plugins-official" = true;
    "feature-dev@claude-plugins-official" = true;
    "frontend-design@claude-plugins-official" = true;
    "hookify@claude-plugins-official" = true;
    "learning-output-style@claude-plugins-official" = true;
    "mcp-server-dev@claude-plugins-official" = true;
    "pr-review-toolkit@claude-plugins-official" = true;
    "ralph-loop@claude-plugins-official" = true;
    "security-guidance@claude-plugins-official" = true;
    "skill-creator@claude-plugins-official" = true;

    # Official LSP plugins
    "pyright-lsp@claude-plugins-official" = true;
    "typescript-lsp@claude-plugins-official" = true;
  }
  # Dev toolchain plugins (require C/C++, Go, Rust toolchains)
  // lib.optionalAttrs devToolchains {
    # Official LSP plugins
    "clangd-lsp@claude-plugins-official" = true;
    "gopls-lsp@claude-plugins-official" = true;
    "rust-analyzer-lsp@claude-plugins-official" = true;
  }
  # Online plugins (require network access to external services)
  // lib.optionalAttrs online {
    # Third-party plugins
    "agent-browser@agent-browser" = true;
    "context7-plugin@context7-marketplace" = true;
  };

  # ----------------------------------------------------------------------------
  # Helpers
  # ----------------------------------------------------------------------------
  mkGithubSource = m: {
    source = "github";
    repo = "${m.github.owner}/${m.github.repo}";
  };

  parsePluginId =
    id:
    let
      parts = lib.splitString "@" id;
    in
    {
      plugin = builtins.head parts;
      marketplace = builtins.elemAt parts 1;
    };

  # ----------------------------------------------------------------------------
  # Derived Settings
  # ----------------------------------------------------------------------------
  extraKnownMarketplaces = lib.mapAttrs (_: m: {
    source = mkGithubSource m;
  }) marketplaces;

  # ----------------------------------------------------------------------------
  # Plugin Bundling
  # ----------------------------------------------------------------------------
  mkPluginBundle =
    homeDir:
    let
      # Unique marketplace names referenced by enabled plugins
      usedMarketplaceNames = lib.unique (
        map (id: (parsePluginId id).marketplace) (builtins.attrNames enabledPlugins)
      );

      # Pre-fetched marketplace sources (shared between plugin cache and manifests)
      marketplaceSrc = lib.genAttrs usedMarketplaceNames (
        name:
        pkgs.fetchFromGitHub {
          inherit (marketplaces.${name}.github) owner repo;
          inherit (marketplaces.${name}) rev hash;
        }
      );

      entries = map (
        id:
        let
          inherit (parsePluginId id) plugin marketplace;
          m = marketplaces.${marketplace};
          src = marketplaceSrc.${marketplace};
          # 12-char commit prefix used as plugin version
          version = builtins.substring 0 12 m.rev;
          pluginSrc = if m.pluginsDir == null then src else "${src}/${m.pluginsDir}/${plugin}";
          cachePath = "cache/${marketplace}/${plugin}/${version}";
        in
        {
          inherit
            plugin
            marketplace
            version
            pluginSrc
            cachePath
            ;
          installPath = "${homeDir}/.claude/plugins/${cachePath}";
        }
      ) (builtins.attrNames enabledPlugins);

      installedPlugins = {
        version = 2;
        plugins = builtins.listToAttrs (
          map (e: {
            name = "${e.plugin}@${e.marketplace}";
            value = [
              {
                scope = "user";
                inherit (e) installPath version;
                installedAt = "1970-01-01T00:00:00.000Z";
                lastUpdated = "1970-01-01T00:00:00.000Z";
              }
            ];
          }) entries
        );
      };

      # Registry that maps marketplace names to their install locations;
      # Claude Code reads this to discover which marketplaces are available.
      knownMarketplaces = lib.genAttrs usedMarketplaceNames (name: {
        source = mkGithubSource marketplaces.${name};
        installLocation = "${homeDir}/.claude/plugins/marketplaces/${name}";
        lastUpdated = "1970-01-01T00:00:00.000Z";
        autoUpdate = false;
      });
    in
    pkgs.runCommand "claude-plugins-bundle" { } ''
      mkdir -p $out/cache $out/marketplaces
      ${lib.concatMapStrings (e: ''
        mkdir -p "$out/cache/${e.marketplace}/${e.plugin}"
        cp -r "${e.pluginSrc}" "$out/${e.cachePath}"
      '') entries}
      ${lib.concatMapStrings (name: ''
        cp -r "${marketplaceSrc.${name}}" "$out/marketplaces/${name}"
      '') usedMarketplaceNames}
      cp ${json.generate "installed_plugins.json" installedPlugins} $out/installed_plugins.json
      cp ${json.generate "known_marketplaces.json" knownMarketplaces} $out/known_marketplaces.json
    '';
in
{
  inherit enabledPlugins extraKnownMarketplaces mkPluginBundle;
}
