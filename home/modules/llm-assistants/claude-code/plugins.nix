{
  pkgs,
  lib,
  enableDevToolchains ? false,
}:

# ==============================================================================
# Claude Code Plugins
# ==============================================================================

let
  # ----------------------------------------------------------------------------
  # Marketplace Definitions
  # ----------------------------------------------------------------------------
  marketplaces = {
    anthropic-agent-skills = {
      github = {
        owner = "anthropics";
        repo = "skills";
      };
      rev = "b0cbd3df1533b396d281a6886d5132f623393a9c";
      hash = "sha256-GzNpraXV85qUwyGs5XDe0zHYr2AazqFppWtH9JvO3QE=";
      pluginsDir = null;
    };

    claude-plugins-official = {
      github = {
        owner = "anthropics";
        repo = "claude-plugins-official";
      };
      rev = "d5c15b861cd23e3102215c26020368ad5134dc47";
      hash = "sha256-ETeWt0onsC/TDVaZLHqm2Qptqds+Cs1PMZ85GgWlBcg=";
      pluginsDir = "plugins";
    };

    agent-browser = {
      github = {
        owner = "vercel-labs";
        repo = "agent-browser";
      };
      rev = "8163f6cdca1aebb9a77f058f1ae93455bbc00974";
      hash = "sha256-b68m3/bhiAPZ4l5C0ike3CMnLaec+997gRwLZfmvOZA=";
      pluginsDir = null;
    };

    context7-marketplace = {
      github = {
        owner = "upstash";
        repo = "context7";
      };
      rev = "800afc31fc49b5c94b6b7f52cbb345b7c11508ba";
      hash = "sha256-MjtCPPcjd/Dc9YkkJp37aNnVYWbU1qk5V2RUc6mIdrM=";
      pluginsDir = null;
    };
  };

  # ----------------------------------------------------------------------------
  # Enabled Plugins
  # ----------------------------------------------------------------------------
  enabledPlugins = {
    # Official skills
    "document-skills@anthropic-agent-skills" = true;
    "example-skills@anthropic-agent-skills" = true;

    # Official plugins
    "code-review@claude-plugins-official" = true;
    "commit-commands@claude-plugins-official" = true;
    "explanatory-output-style@claude-plugins-official" = true;
    "feature-dev@claude-plugins-official" = true;
    "hookify@claude-plugins-official" = true;
    "learning-output-style@claude-plugins-official" = true;
    "pr-review-toolkit@claude-plugins-official" = true;
    "ralph-loop@claude-plugins-official" = true;
    "security-guidance@claude-plugins-official" = true;

    # Official LSP plugins
    "pyright-lsp@claude-plugins-official" = true;
    "typescript-lsp@claude-plugins-official" = true;

    # Third-party plugins
    "agent-browser@agent-browser" = true;
    "context7-plugin@context7-marketplace" = true;
  }
  # Dev toolchain plugins (require C/C++, Go, Rust toolchains)
  // lib.optionalAttrs enableDevToolchains {
    # Official LSP plugins
    "clangd-lsp@claude-plugins-official" = true;
    "gopls-lsp@claude-plugins-official" = true;
    "rust-analyzer-lsp@claude-plugins-official" = true;
  };

  # ----------------------------------------------------------------------------
  # Derived: settings.json fields
  # ----------------------------------------------------------------------------
  extraKnownMarketplaces = lib.mapAttrs (_: m: {
    source = {
      source = "github";
      repo = "${m.github.owner}/${m.github.repo}";
    };
  }) marketplaces;

  # ----------------------------------------------------------------------------
  # Plugin Bundling
  # ----------------------------------------------------------------------------
  json = pkgs.formats.json { };

  mkPluginBundle =
    homeDir:
    let
      entries = map (
        id:
        let
          parts = lib.splitString "@" id;
          plugin = builtins.head parts;
          marketplace = builtins.elemAt parts 1;
          m = marketplaces.${marketplace};
          src = pkgs.fetchFromGitHub {
            inherit (m.github) owner repo;
            inherit (m) rev hash;
          };
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
    in
    pkgs.runCommand "claude-plugins-bundle" { } ''
      mkdir -p $out/cache
      ${lib.concatMapStrings (e: ''
        mkdir -p "$out/cache/${e.marketplace}/${e.plugin}"
        cp -r "${e.pluginSrc}" "$out/${e.cachePath}"
      '') entries}
      cp ${json.generate "installed_plugins.json" installedPlugins} $out/installed_plugins.json
    '';
in
{
  inherit enabledPlugins extraKnownMarketplaces mkPluginBundle;
}
