return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        marksman = {
          handlers = {
            -- Marksman publishes diagnostics for every .md in the workspace. In big repos
            -- (e.g. websim-tasks, ~4k files) that makes Neovim create hundreds of hidden
            -- buffers and balloons memory. Only keep diagnostics for loaded buffers.
            ["textDocument/publishDiagnostics"] = function(err, result, ctx)
              local bufnr = vim.fn.bufnr(vim.uri_to_fname(result.uri))
              if bufnr == -1 or not vim.api.nvim_buf_is_loaded(bufnr) then
                return
              end
              return vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx)
            end,
          },
        },
      },
    },
  },
}
