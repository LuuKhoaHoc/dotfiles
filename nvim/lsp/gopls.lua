local Lsp = require "utils.lsp"
-- go install golang.org/x/tools/gopls@latest
return {
  cmd = { "gopls" },
  on_attach = Lsp.on_attach,
  filetypes = { "go", "gomod", "gowork", "gotmpl" },
  root_markers = { "go.sum", "go.mod", ".git" },
  settings = {
    gopls = {
      gofumpt = true,
      staticcheck = true,
      usePlaceholders = true,
      completeUnimported = true,
      analyses = {
        unusedparams = true,
        nilness = true,
        shadow = true,
      },
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    },
  },
}
