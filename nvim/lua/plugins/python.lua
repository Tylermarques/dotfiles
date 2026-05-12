return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ty = {
          on_attach = function(client, _)
            -- Disable ty's definition provider to avoid duplicates with basedpyright
            client.server_capabilities.definitionProvider = false
          end,
        },
      },
    },
  },
}
