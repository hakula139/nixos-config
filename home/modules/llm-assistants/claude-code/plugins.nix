# ==============================================================================
# Claude Code Plugins
# ==============================================================================

{
  pkgs,
  lib,
  inputs,
  workmuxMarketplace,
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
    agent-browser = {
      github = {
        owner = "vercel-labs";
        repo = "agent-browser";
      };
      rev = "7379f7dbea76ad8dbf47f177349c4c3ce9263dcb"; # v0.30.1
      hash = "sha256-NWd9qENjHCoOMgd5QWxleBvCn+ShDIEW7oOU5DC2zcI=";
      pluginsDir = null;
    };

    anthropic-agent-skills = {
      github = {
        owner = "anthropics";
        repo = "skills";
      };
      source = inputs.anthropics-skills;
      version = "flake-input";
      pluginsDir = null;
    };

    claude-plugins-official = {
      github = {
        owner = "anthropics";
        repo = "claude-plugins-official";
      };
      rev = "5fada75bc8d1a419292dc417a99c0552dd1ea885"; # 2026-06-25
      hash = "sha256-F7qYq5TYcjxJmewiBnIvYeJOnJ/g61qg3as4sGh1C7Q=";
      pluginsDir = "plugins";
    };

    context7-marketplace = {
      github = {
        owner = "upstash";
        repo = "context7";
      };
      rev = "a914a8693488f1a7b37581de176ad1f19def8e64"; # 2026-06-24
      hash = "sha256-GCM3dGVHZN4QpB10J/tgPfCfv7fQ1xsryTxMrsVAj6g=";
      pluginsDir = null;
    };

    openai-codex = {
      github = {
        owner = "openai";
        repo = "codex-plugin-cc";
      };
      rev = "80c31f99570876c3ef40327838b0a2ca1ae2cd9c"; # v1.0.5
      hash = "sha256-KJNJyAYVBsA6On/mrx9GSSQmjrwCHfQZAr+c3BZYUc0=";
      pluginsDir = "plugins";
    };

    workmux = workmuxMarketplace;
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

    # Workmux plugin
    "workmux-status@workmux" = true;
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
