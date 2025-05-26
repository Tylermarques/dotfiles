-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<Tab>", ":bnext<CR>")
vim.keymap.set("n", "<S-Tab>", ":bprev<CR>")

vim.keymap.set("n", "<C-h>", "<Cmd>NvimTmuxNavigateLeft<CR>", { silent = true })
vim.keymap.set("n", "<C-j>", "<Cmd>NvimTmuxNavigateDown<CR>", { silent = true })
vim.keymap.set("n", "<C-k>", "<Cmd>NvimTmuxNavigateUp<CR>", { silent = true })
vim.keymap.set("n", "<C-l>", "<Cmd>NvimTmuxNavigateRight<CR>", { silent = true })
vim.keymap.set("n", "<C-\\>", "<Cmd>NvimTmuxNavigateLastActive<CR>", { silent = true })
vim.keymap.set("n", "<C-Space>", "<Cmd>NvimTmuxNavigateNavigateNext<CR>", { silent = true })

-- Window resizing with repeatable keys
local function setup_resize_mode()
  local function resize_and_repeat(direction)
    return function()
      if direction == "h" then
        vim.cmd("vertical resize -5")
      elseif direction == "l" then
        vim.cmd("vertical resize +5")
      elseif direction == "j" then
        vim.cmd("resize -5")
      elseif direction == "k" then
        vim.cmd("resize +5")
      end
      
      -- Set up temporary keymaps for repeating
      local opts = { silent = true, buffer = false }
      vim.keymap.set("n", "h", resize_and_repeat("h"), opts)
      vim.keymap.set("n", "l", resize_and_repeat("l"), opts)
      vim.keymap.set("n", "j", resize_and_repeat("j"), opts)
      vim.keymap.set("n", "k", resize_and_repeat("k"), opts)
      vim.keymap.set("n", "<Esc>", function()
        vim.keymap.del("n", "h")
        vim.keymap.del("n", "l")
        vim.keymap.del("n", "j")
        vim.keymap.del("n", "k")
        vim.keymap.del("n", "<Esc>")
      end, opts)
    end
  end
  
  vim.keymap.set("n", "<leader>rh", resize_and_repeat("h"), { desc = "Resize window left (repeatable)" })
  vim.keymap.set("n", "<leader>rl", resize_and_repeat("l"), { desc = "Resize window right (repeatable)" })
  vim.keymap.set("n", "<leader>rj", resize_and_repeat("j"), { desc = "Resize window down (repeatable)" })
  vim.keymap.set("n", "<leader>rk", resize_and_repeat("k"), { desc = "Resize window up (repeatable)" })
end

setup_resize_mode()
