# ==============================================================================
# Claude Code Plugins
# ==============================================================================

{
  pkgs,
  lib,
  inputs,
  codexEnabled ? false,
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
      source = inputs.agent-skills;
      version = "flake-input";
      pluginsDir = null;
    };

    claude-plugins-official = {
      github = {
        owner = "anthropics";
        repo = "claude-plugins-official";
      };
      rev = "b392f51899343f35a203260a4b344803de236d13"; # 2026-05-01
      hash = "sha256-zUogHhL7MWXqpRDzjKI3giqyWJMArQDoSKooxhwfj/8=";
      pluginsDir = "plugins";
    };

    agent-browser = {
      github = {
        owner = "vercel-labs";
        repo = "agent-browser";
      };
      rev = "717d1b09e1c841a4c0206033886a1a861e3ca5d9"; # v0.26.0
      hash = "sha256-q3UcFTB8OMOrfx5xcNPtBBAwOxoscwrjGg+y8tdETm0=";
      pluginsDir = null;
    };

    context7-marketplace = {
      github = {
        owner = "upstash";
        repo = "context7";
      };
      rev = "795d5da720e16c417ae30a548a475672ae35e92f"; # 2026-04-30
      hash = "sha256-FS4JNh9QXCicV2mRuN7jMos4nEbr7eqO/g97HLQJAyU=";
      pluginsDir = null;
    };

    openai-codex = {
      github = {
        owner = "openai";
        repo = "codex-plugin-cc";
      };
      rev = "807e03ac9d5aa23bc395fdec8c3767500a86b3cf"; # v1.0.4
      hash = "sha256-zWddz18c3E15TPuEvjMkBkrwiFlK3ZqIG5YP5xX6ZII=";
      pluginsDir = "plugins";
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
  # Codex plugin (requires the codex CLI from the codex module)
  // lib.optionalAttrs codexEnabled {
    "codex@openai-codex" = true;
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
        let
          m = marketplaces.${name};
        in
        m.source or (pkgs.fetchFromGitHub {
          inherit (m.github) owner repo;
          inherit (m) rev hash;
        })
      );

      entries = map (
        id:
        let
          inherit (parsePluginId id) plugin marketplace;
          m = marketplaces.${marketplace};
          src = marketplaceSrc.${marketplace};
          # 12-char commit prefix used as plugin version
          version = m.version or (builtins.substring 0 12 m.rev);
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
