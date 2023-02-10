local overrides = require "custom.plugins.overrides"
return {
  ["neovim/nvim-lspconfig"] = {
    config = function()
      require "plugins.configs.lspconfig"
      require "custom.plugins.lspconfig"
    end,
  },
    -- overrde plugin configs
  ["nvim-treesitter/nvim-treesitter"] = {
    override_options = overrides.treesitter,
  },

  ["jose-elias-alvarez/null-ls.nvim"] = {
      after = "nvim-lspconfig",
      config = function()
         require "custom.plugins.null-ls"
      end,
 },

  ["williamboman/mason.nvim"] = {
    override_options = overrides.mason,
  },

--  ["kyazdani42/nvim-tree.lua"] = {
--    override_options = overrides.nvimtree,
--  },
  ["alexghergh/nvim-tmux-navigation"] = {
     config = function()
       require'nvim-tmux-navigation'.setup {
            disable_when_zoomed = true, -- defaults to false
            keybindings = {
                left = "<C-h>",
                down = "<C-j>",
                up = "<C-k>",
                right = "<C-l>",
                last_active = "<C-\\>",
                next = "<C-Space>",
            }
        }
    end
  },
  ["tamton-aquib/duck.nvim"] = {config = function()
        vim.keymap.set('n', '<leader>dd', function() require("duck").hatch() end, {})
        vim.keymap.set('n', '<leader>dk', function() require("duck").cook() end, {})
    end},
  ['puremourning/vimspector'] = {
    config = function()
      require('custom.plugins.vimspector').setup()
    end
  }
}
