return {
  "mfussenegger/nvim-dap-python",
  keys = {
    {
      "<leader>dm",
      function()
        require("dap-python").test_method()
      end,
      desc = "Debug Python File",
    },
  },
}
