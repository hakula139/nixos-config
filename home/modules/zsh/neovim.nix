{ pkgs, ... }:

# ==============================================================================
# Neovim (Text Editor)
# ==============================================================================

{
  programs.neovim = {
    enable = true;
    vimAlias = true;
    viAlias = true;
    defaultEditor = false;

    # --------------------------------------------------------------------------
    # Plugins
    # --------------------------------------------------------------------------
    plugins = with pkgs.vimPlugins; [
      # Syntax highlighting with tree-sitter
      {
        plugin = nvim-treesitter.withAllGrammars;
        type = "lua";
        config = ''
          require('nvim-treesitter.configs').setup {
            highlight = { enable = true },
            indent = { enable = true },
          }
        '';
      }

      # Color scheme
      {
        plugin = catppuccin-nvim;
        type = "lua";
        config = ''
          require('catppuccin').setup {
            flavour = 'mocha',
            transparent_background = true,
          }
          vim.cmd.colorscheme 'catppuccin'
        '';
      }

      # Status line
      {
        plugin = lualine-nvim;
        type = "lua";
        config = ''
          require('lualine').setup {
            options = {
              theme = 'catppuccin',
              component_separators = { left = '│', right = '│' },
              section_separators = { left = "", right = "" },
            },
          }
        '';
      }

      # File explorer
      {
        plugin = oil-nvim;
        type = "lua";
        config = ''
          require('oil').setup {
            view_options = { show_hidden = true },
          }
          vim.keymap.set('n', '-', '<cmd>Oil<cr>', { desc = 'Open parent directory' })
        '';
      }

      # Fuzzy finder
      {
        plugin = fzf-lua;
        type = "lua";
        config = ''
          local fzf = require('fzf-lua')
          fzf.setup {}
          vim.keymap.set('n', '<leader>ff', fzf.files, { desc = 'Find files' })
          vim.keymap.set('n', '<leader>fg', fzf.live_grep, { desc = 'Live grep' })
          vim.keymap.set('n', '<leader>fb', fzf.buffers, { desc = 'Buffers' })
          vim.keymap.set('n', '<leader>fh', fzf.help_tags, { desc = 'Help tags' })
        '';
      }

      # Git integration
      {
        plugin = gitsigns-nvim;
        type = "lua";
        config = ''
          require('gitsigns').setup {
            signs = {
              add = { text = '│' },
              change = { text = '│' },
              delete = { text = '_' },
              topdelete = { text = '‾' },
              changedelete = { text = '~' },
            },
          }
        '';
      }

      # Auto pairs
      {
        plugin = nvim-autopairs;
        type = "lua";
        config = ''
          require('nvim-autopairs').setup {}
        '';
      }

      # Comment toggling
      {
        plugin = comment-nvim;
        type = "lua";
        config = ''
          require('Comment').setup {}
        '';
      }

      # Surround text objects
      vim-surround

      # Better repeat with .
      vim-repeat
    ];

    # --------------------------------------------------------------------------
    # Core configuration
    # --------------------------------------------------------------------------
    extraLuaConfig = ''
      -- =======================================================================
      -- Options
      -- =======================================================================

      local opt = vim.opt

      -- UI
      opt.number = true
      opt.relativenumber = true
      opt.cursorline = true
      opt.signcolumn = 'yes'
      opt.termguicolors = true
      opt.showmode = false -- lualine shows mode
      opt.showcmd = true
      opt.laststatus = 3 -- global statusline
      opt.scrolloff = 8
      opt.sidescrolloff = 8

      -- Editing
      opt.tabstop = 2
      opt.shiftwidth = 2
      opt.softtabstop = 2
      opt.expandtab = true
      opt.smartindent = true
      opt.autoindent = true
      opt.wrap = false

      -- Search
      opt.ignorecase = true
      opt.smartcase = true
      opt.incsearch = true
      opt.hlsearch = true

      -- Splits
      opt.splitright = true
      opt.splitbelow = true

      -- Clipboard (system clipboard integration)
      opt.clipboard = 'unnamedplus'

      -- Files
      opt.hidden = true
      opt.autoread = true
      opt.backup = false
      opt.writebackup = false
      opt.swapfile = false
      opt.undofile = true

      -- Misc
      opt.mouse = 'a'
      opt.updatetime = 250
      opt.timeoutlen = 500
      opt.list = true
      opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
      opt.showmatch = true
      opt.completeopt = { 'menu', 'menuone', 'noselect' }

      -- =======================================================================
      -- Keymaps
      -- =======================================================================

      local keymap = vim.keymap.set

      -- Leader key
      vim.g.mapleader = ' '
      vim.g.maplocalleader = ' '

      -- Clear search highlighting
      keymap('n', '<Esc>', '<cmd>nohlsearch<cr>', { desc = 'Clear search highlight' })

      -- Better window navigation
      keymap('n', '<C-h>', '<C-w>h', { desc = 'Go to left window' })
      keymap('n', '<C-j>', '<C-w>j', { desc = 'Go to lower window' })
      keymap('n', '<C-k>', '<C-w>k', { desc = 'Go to upper window' })
      keymap('n', '<C-l>', '<C-w>l', { desc = 'Go to right window' })

      -- Resize windows
      keymap('n', '<C-Up>', '<cmd>resize +2<cr>', { desc = 'Increase window height' })
      keymap('n', '<C-Down>', '<cmd>resize -2<cr>', { desc = 'Decrease window height' })
      keymap('n', '<C-Left>', '<cmd>vertical resize -2<cr>', { desc = 'Decrease window width' })
      keymap('n', '<C-Right>', '<cmd>vertical resize +2<cr>', { desc = 'Increase window width' })

      -- Buffer navigation
      keymap('n', '<S-h>', '<cmd>bprevious<cr>', { desc = 'Previous buffer' })
      keymap('n', '<S-l>', '<cmd>bnext<cr>', { desc = 'Next buffer' })
      keymap('n', '<leader>bd', '<cmd>bdelete<cr>', { desc = 'Delete buffer' })

      -- Stay in visual mode when indenting
      keymap('v', '<', '<gv', { desc = 'Indent left' })
      keymap('v', '>', '>gv', { desc = 'Indent right' })

      -- Move lines up / down
      keymap('v', 'J', ":m '>+1<cr>gv=gv", { desc = 'Move selection down' })
      keymap('v', 'K', ":m '<-2<cr>gv=gv", { desc = 'Move selection up' })

      -- Better paste (don't overwrite register)
      keymap('v', 'p', '"_dP', { desc = 'Paste without overwriting register' })

      -- Quick save
      keymap('n', '<leader>w', '<cmd>w<cr>', { desc = 'Save file' })
      keymap('n', '<leader>q', '<cmd>q<cr>', { desc = 'Quit' })

      -- =======================================================================
      -- Autocommands
      -- =======================================================================

      local augroup = vim.api.nvim_create_augroup
      local autocmd = vim.api.nvim_create_autocmd

      -- Highlight on yank
      autocmd('TextYankPost', {
        group = augroup('highlight_yank', { clear = true }),
        callback = function()
          vim.hl.on_yank { timeout = 200 }
        end,
      })

      -- Restore cursor position
      autocmd('BufReadPost', {
        group = augroup('restore_cursor', { clear = true }),
        callback = function()
          local mark = vim.api.nvim_buf_get_mark(0, '"')
          local lcount = vim.api.nvim_buf_line_count(0)
          if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
          end
        end,
      })

      -- Auto-resize splits when terminal resizes
      autocmd('VimResized', {
        group = augroup('resize_splits', { clear = true }),
        callback = function()
          vim.cmd('tabdo wincmd =')
        end,
      })

      -- Remove trailing whitespace on save
      autocmd('BufWritePre', {
        group = augroup('trim_whitespace', { clear = true }),
        pattern = '*',
        callback = function()
          local save = vim.fn.winsaveview()
          vim.cmd([[%s/\s\+$//e]])
          vim.fn.winrestview(save)
        end,
      })
    '';
  };
}
