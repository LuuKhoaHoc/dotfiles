return {
  'nabekou29/js-i18n.nvim',
  dependencies = {
    'neovim/nvim-lspconfig',
    'nvim-treesitter/nvim-treesitter',
    'nvim-lua/plenary.nvim',
  },
  event = { 'BufReadPre', 'BufNewFile' },
  opts = {
    primary_language = {},                                                -- The default language to display (initial setting for displaying virtual text, etc.)
    translation_source = { '**/{locales,messages,translations}/*.json' }, -- Pattern for translation resources
    key_separator = '.',                                                  -- Key separator
    virt_text = {
      enabled = true,                                                     -- Enable virtual text display
      conceal_key = false,                                                -- Hide keys and display only translations
      fallback = false,                                                   -- Fallback if the selected virtual text cannot be displayed
      max_length = 0,                                                     -- Maximum length of virtual text. 0 means unlimited.
      max_width = 0,                                                      -- Maximum width of virtual text. 0 means unlimited. (`max_length` takes precedence.)
    },
    diagnostic = {
      enabled = true,                          -- Enable the display of diagnostic information
      severity = vim.diagnostic.severity.WARN, -- Severity level of diagnostic information
    },
  },
}
