-- CSS Language Server for CSS completions
-- Install: npm install -g vscode-css-languageserver-bin
return {
  cmd = { "vscode-css-language-server", "--stdio" },
  filetypes = {
    "css",
    "scss",
    "sass",
    "less",
    "postcss",
  },
  root_markers = {
    "package.json",
    "tsconfig.json",
    "jsconfig.json",
    ".git",
  },
  init_options = {
    provideFormatter = true,
    provideCompletionItems = true,
    provideDefinition = true,
    provideHover = true,
    provideReferences = true,
    provideDocumentHighlights = true,
    provideDocumentSymbols = true,
    provideSelectionRanges = true,
  },
  settings = {
    css = {
      lint = {
        compatibleVendorPrefixes = "ignore",
        vendorPrefix = "ignore",
        duplicateProperties = "ignore",
        emptyRules = "ignore",
        importStatement = "ignore",  -- Disable @import warning
        boxModel = "ignore",
        universalSelector = "ignore",
        zeroUnits = "ignore",
        fontFaceProperties = "ignore",
        hexColorLength = "ignore",
        argumentsInColorFunction = "ignore",
        unknownProperties = "ignore",
        ieHack = "ignore",
        unknownVendorSpecificProperties = "ignore",
        propertyIgnoredDueToDisplay = "ignore",
        important = "ignore",
        float = "ignore",
        idSelector = "ignore",
        unknownAtRules = "ignore",  -- Disable @custom-variant warning
      },
      validate = true,
    },
    scss = {
      lint = {
        unknownAtRules = "ignore",
      },
      validate = true,
    },
    less = {
      lint = {
        unknownAtRules = "ignore",
      },
      validate = true,
    },
  },
}
