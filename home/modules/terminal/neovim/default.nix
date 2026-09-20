# ==============================================================================
# Neovim (Text Editor)
# ==============================================================================

{
  pkgs,
  ...
}:

{
  programs.neovim = {
    enable = true;
    vimAlias = true;
    viAlias = true;
    defaultEditor = false;
    withPython3 = true;
    withRuby = true;

    # --------------------------------------------------------------------------
    # Plugins
    # --------------------------------------------------------------------------
    plugins = with pkgs.vimPlugins; [
      # Syntax highlighting with tree-sitter
      nvim-treesitter.withAllGrammars

      # Color scheme
      catppuccin-nvim

      # Status line
      lualine-nvim

      # File explorer
      oil-nvim

      # Fuzzy finder
      fzf-lua

      # Git integration
      gitsigns-nvim

      # Auto pairs
      nvim-autopairs

      # Comment toggling
      comment-nvim

      # Surround text objects
      vim-surround

      # Better repeat with .
      vim-repeat
    ];

    # --------------------------------------------------------------------------
    # Lua configuration
    # --------------------------------------------------------------------------
    initLua = builtins.readFile ./init.lua;
  };
}
