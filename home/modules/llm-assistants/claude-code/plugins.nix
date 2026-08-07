# ==============================================================================
# Claude Code Plugins
# ==============================================================================

{
  pkgs,
  lib,
  inputs,
  enableDevToolchains ? false,
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
      rev = "93cdda5709e8861c0c26b0b955d8d746e9fda0d7"; # v0.33.2
      hash = "sha256-sAWIuHX3cHEpVQBh2WRIJ6zurB0nNza0QmX7k0zM4k0=";
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
      rev = "60f5e338b2aa4a757b115a3bbea635d6727ea530"; # 2026-08-05
      hash = "sha256-OvdH0DW6vnfvc9/J9lI/X/2sHc5qMpot8zc+cq4FFQg=";
      pluginsDir = "plugins";
    };

    context7-marketplace = {
      github = {
        owner = "upstash";
        repo = "context7";
      };
      rev = "594a73133e14631af8c915a1b4f2c8039c964fe1"; # 2026-07-30
      hash = "sha256-Msvr7srpy+2HzxYKsPzo0hhzW7E1/ktTwdBEtuFMgRE=";
      pluginsDir = null;
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
