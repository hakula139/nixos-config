# ==================================================================================================
# Claude Code Plugins
# ==================================================================================================

{
  lib,
  enableDevToolchains,
}:

let
  # ------------------------------------------------------------------------------------------------
  # Marketplace definitions
  # ------------------------------------------------------------------------------------------------
  marketplaces = {
    claude-plugins-official = "anthropics/claude-plugins-official";
    workmux = "raine/workmux";
  };

  # ------------------------------------------------------------------------------------------------
  # Enabled plugins
  # ------------------------------------------------------------------------------------------------
  enabledPlugins = {
    "skill-creator@claude-plugins-official" = true;
    "workmux-status@workmux" = true;
  }
  // lib.optionalAttrs enableDevToolchains {
    "clangd-lsp@claude-plugins-official" = true;
    "gopls-lsp@claude-plugins-official" = true;
    "pyright-lsp@claude-plugins-official" = true;
    "rust-analyzer-lsp@claude-plugins-official" = true;
    "typescript-lsp@claude-plugins-official" = true;
  };

  # ------------------------------------------------------------------------------------------------
  # Derived settings
  # ------------------------------------------------------------------------------------------------
  extraKnownMarketplaces = lib.mapAttrs (_: repo: {
    source = {
      source = "github";
      inherit repo;
    };
  }) marketplaces;
in
{
  inherit enabledPlugins extraKnownMarketplaces;
}
