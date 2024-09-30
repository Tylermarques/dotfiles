local lspconfig = require("lspconfig")
lspconfig.beancount.setup = {
  init_options = {
    journal_file = "~/Documents/beancount/personal.beancount",
  },
}
