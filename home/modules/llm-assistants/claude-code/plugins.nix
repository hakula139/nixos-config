# ==============================================================================
# Claude Code Plugins
# ==============================================================================

{
  pkgs,
  lib,
  enableDevToolchains ? false,
}:

let
  json = pkgs.formats.json { };

  # ----------------------------------------------------------------------------
  # Marketplace Definitions
  # ----------------------------------------------------------------------------
  marketplaces = {
    claude-plugins-official = {
      github = {
        owner = "anthropics";
        repo = "claude-plugins-official";
      };
      rev = "ea0a38e1d671aa18a30431c9160e31193dc9860b"; # 2026-09-17
      hash = "sha256-Jcbbc+mOXg9ca1dBO+gXXEpJ2SDqqjyKbqvipiTDR4k=";
      pluginsDir = "plugins";
    };

    openai-codex = {
      github = {
        owner = "openai";
        repo = "codex-plugin-cc";
      };
      rev = "db52e28f4d9ded852ab3942cea316258ae4ef346"; # v1.0.6
      hash = "sha256-S/R4kHTcIHBcG0TRX063C7ILXZZm0oMqunchPGg6ToU=";
      pluginsDir = "plugins";
    };

    workmux = {
      github = {
        owner = "raine";
        repo = "workmux";
      };
      inherit (pkgs.workmux) version;
      source = pkgs.workmux.src;
      pluginsDir = null;
    };
  };

  marketplaceSources = lib.mapAttrs (
    _: m:
    m.source or (pkgs.fetchFromGitHub {
      inherit (m.github) owner repo;
      inherit (m) rev hash;
    })
  ) marketplaces;

  # ----------------------------------------------------------------------------
  # Enabled Plugins
  # ----------------------------------------------------------------------------
  enabledPlugins = {
    # Official plugins
    "skill-creator@claude-plugins-official" = true;

    # Official LSP plugins
    "pyright-lsp@claude-plugins-official" = true;
    "typescript-lsp@claude-plugins-official" = true;

    # Third-party plugins
    "codex@openai-codex" = true;
    "workmux-status@workmux" = true;
  }
  # Dev toolchain plugins (require C/C++, Go, Rust toolchains)
  // lib.optionalAttrs enableDevToolchains {
    # Official LSP plugins
    "clangd-lsp@claude-plugins-official" = true;
    "gopls-lsp@claude-plugins-official" = true;
    "rust-analyzer-lsp@claude-plugins-official" = true;
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

      entries = map (
        id:
        let
          inherit (parsePluginId id) plugin marketplace;
          m = marketplaces.${marketplace};
          src = marketplaceSources.${marketplace};
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
        cp -r "${marketplaceSources.${name}}" "$out/marketplaces/${name}"
      '') usedMarketplaceNames}
      cp ${json.generate "installed_plugins.json" installedPlugins} $out/installed_plugins.json
      cp ${json.generate "known_marketplaces.json" knownMarketplaces} $out/known_marketplaces.json
    '';
in
{
  inherit
    enabledPlugins
    extraKnownMarketplaces
    mkPluginBundle
    ;
}
