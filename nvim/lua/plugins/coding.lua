local completion = vim.g.completion_mode or "blink" -- or 'native'

local trigger_text = ";"

return { -- Setup Copilot
{
    "github/copilot.vim",
    -- NOTE: Pin version to avoid breaking changes
    version = "v1.42.0",
    event = "VeryLazy",
    config = function()
        -- For copilot.vim
        -- enable copilot for specific filetypes
        vim.g.copilot_filetypes = {
            ["TelescopePrompt"] = false,
            ["grug-far"] = false,
            ["grug-far-history"] = false,
            ["copilot-chat"] = false
        }

        -- Set to true to assume that copilot is already mapped
        vim.g.copilot_assume_mapped = true
        -- Set workspace folders
        vim.g.copilot_workspace_folders = "~/Dev-Work"

        -- Setup keymaps
        local keymap = vim.keymap.set
        local opts = {
            silent = true
        }

        -- Set <C-y> to accept copilot suggestion
        keymap("i", "<C-y>", 'copilot#Accept("\\<CR>")', {
            expr = true,
            replace_keycodes = false
        })

        -- Set <C-i> to accept line
        keymap("i", "<C-i>", "<Plug>(copilot-accept-line)", opts)

        -- Set <C-j> to next suggestion, <C-k> to previous suggestion
        keymap("i", "<C-j>", "<Plug>(copilot-next)", opts)
        keymap("i", "<C-k>", "<Plug>(copilot-previous)", opts)

        -- Set <C-d> to dismiss suggestion
        keymap("i", "<C-d>", "<Plug>(copilot-dismiss)", opts)
    end
}, -- Autocomplete, refer to https://cmp.saghen.dev/#compared-to-built-in-completion for more information
{
    "saghen/blink.cmp",
    event = "InsertEnter",
    enable = completion == "blink",
    -- use a release tag to download pre-built binaries
    -- version = "1.*",
    branch = "main", -- NOTE: use main branch for latest features and fixes, use version tag for stable releases
    -- AND/OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
    -- build = 'cargo build --release',
    -- If you use nix, you can build from source using latest nightly rust with:
    -- build = 'nix run .#build-plugin',
    dependencies = {
        -- optional: provides snippets for the snippet source
        "L3MON4D3/LuaSnip",
        version = "v2.*",
        build = (function()
            -- Build Step is needed for regex support in snippets.
            -- This step is not supported in many windows environments.
            -- Remove the below condition to re-enable on windows.
            if vim.fn.has "win32" == 1 or vim.fn.executable "make" == 0 then
                return
            end
            return "make install_jsregexp"
        end)(),
        dependencies = { -- `friendly-snippets` contains a variety of premade snippets.
        {
            "rafamadriz/friendly-snippets",
            config = function()
                require("luasnip.loaders.from_vscode").lazy_load()
                require("luasnip.loaders.from_vscode").lazy_load {
                    paths = {vim.fn.stdpath "config" .. "/snippets"}
                }
            end
        }}
    },
    ---@module 'blink.cmp'
    -- Refer https://cmp.saghen.dev/installation.html
    opts = {
        -- 'default' (recommended) for mappings similar to built-in completions (C-y to accept)
        -- 'super-tab' for mappings similar to vscode (tab to accept)
        -- 'enter' for enter to accept
        -- 'none' for no mappings
        --
        -- All presets have the following mappings:
        -- C-space: Open menu or open docs if already open
        -- C-n/C-p or Up/Down: Select next/previous item
        -- C-e: Hide menu
        -- C-k: Toggle signature help (if signature.enabled = true)
        --
        -- See :h blink-cmp-config-keymap for defining your own keymap
        keymap = {
            preset = "enter"
        },
        completion = {
            accept = {
                -- experimental auto-brackets support
                auto_brackets = {
                    enabled = true
                }
            },
            menu = {
                draw = {
                    treesitter = {"lsp"}
                }
            },
            documentation = {
                auto_show = true,
                auto_show_delay_ms = 200
            },
            ghost_text = {
                enabled = vim.g.ai_cmp
            }
        },
        -- Experimental signature help support
        signature = {
            enabled = false
        },
        appearance = {
            -- Sets the fallback highlight groups to nvim-cmp's highlight groups
            -- Useful for when your theme doesn't support blink.cmp
            -- Will be removed in a future release
            use_nvim_cmp_as_default = true,
            -- Set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
            nerd_font_variant = "mono"
        },
        snippets = {
            preset = "luasnip"
        },
        sources = {
            default = {"lsp", "path", "snippets", "buffer"},
            providers = {
                lsp = {
                    name = "lsp",
                    enabled = true,
                    module = "blink.cmp.sources.lsp",
                    kind = "LSP",
                    min_keyword_length = 0,
                    -- When linking markdown notes, I would get snippets and text in the
                    -- suggestions, I want those to show only if there are no LSP
                    -- suggestions
                    --
                    -- Enabled fallbacks as this seems to be working now
                    -- Disabling fallbacks as my snippets wouldn't show up when editing
                    -- lua files
                    -- fallbacks = { "snippets", "buffer" },
                    score_offset = 90 -- the higher the number, the higher the priority
                },
                path = {
                    name = "Path",
                    module = "blink.cmp.sources.path",
                    score_offset = 25,
                    -- When typing a path, I would get snippets and text in the
                    -- suggestions, I want those to show only if there are no path
                    -- suggestions
                    fallbacks = {"snippets", "buffer"},
                    -- min_keyword_length = 2,
                    opts = {
                        trailing_slash = false,
                        label_trailing_slash = true,
                        get_cwd = function(context)
                            return vim.fn.expand(("#%d:p:h"):format(context.bufnr))
                        end,
                        show_hidden_files_by_default = true
                    }
                },
                buffer = {
                    name = "Buffer",
                    enabled = true,
                    max_items = 3,
                    module = "blink.cmp.sources.buffer",
                    min_keyword_length = 0,
                    score_offset = 15 -- the higher the number, the higher the priority
                },
                snippets = {
                    name = "snippets",
                    enabled = true,
                    max_items = 15,
                    min_keyword_length = 2,
                    module = "blink.cmp.sources.snippets",
                    score_offset = 85, -- the higher the number, the higher the priority
                    -- Only show snippets if I type the trigger_text characters, so
                    -- to expand the "bash" snippet, if the trigger_text is ";" I have to
                    should_show_items = function()
                        local col = vim.api.nvim_win_get_cursor(0)[2]
                        local before_cursor = vim.api.nvim_get_current_line():sub(1, col)
                        -- NOTE: remember that `trigger_text` is modified at the top of the file
                        return before_cursor:match(trigger_text .. "%w*$") ~= nil
                    end,
                    -- After accepting the completion, delete the trigger_text characters
                    -- from the final inserted text
                    -- Modified transform_items function based on suggestion by `synic` so
                    -- that the luasnip source is not reloaded after each transformation
                    -- https://github.com/linkarzu/dotfiles-latest/discussions/7#discussion-7849902
                    -- NOTE: I also tried to add the ";" prefix to all of the snippets loaded from
                    -- friendly-snippets in the luasnip.lua file, but I was unable to do
                    -- so, so I still have to use the transform_items here
                    -- This removes the ";" only for the friendly-snippets snippets
                    transform_items = function(_, items)
                        local line = vim.api.nvim_get_current_line()
                        local col = vim.api.nvim_win_get_cursor(0)[2]
                        local before_cursor = line:sub(1, col)
                        local start_pos, end_pos = before_cursor:find(trigger_text .. "[^" .. trigger_text .. "]*$")
                        if start_pos then
                            for _, item in ipairs(items) do
                                if not item.trigger_text_modified then
                                    ---@diagnostic disable-next-line: inject-field
                                    item.trigger_text_modified = true
                                    item.textEdit = {
                                        newText = item.insertText or item.label,
                                        range = {
                                            start = {
                                                line = vim.fn.line(".") - 1,
                                                character = start_pos - 1
                                            },
                                            ["end"] = {
                                                line = vim.fn.line(".") - 1,
                                                character = end_pos
                                            }
                                        }
                                    }
                                end
                            end
                        end
                        return items
                    end
                }
            }
        },
        fuzzy = {
            implementation = "prefer_rust_with_warning"
        },
        -- Disable cmdline completions
        cmdline = {
            enabled = false
        },
        -- Disable per file type
        enabled = function()
            return not vim.tbl_contains({"copilot-chat"}, vim.bo.filetype) and
                       not vim.tbl_contains({"codecompanion"}, vim.bo.filetype) and vim.bo.buftype ~= "prompt" and
                       vim.b.completion ~= false
        end
    },
    -- without having to redefine it
    opts_extend = {"sources.completion.enabled_providers", "sources.compat", -- Support nvim-cmp source
    "sources.default"}
}, -- Lazydev
{
    "folke/lazydev.nvim",
    opts = {
        library = {{
            path = "${3rd}/luv/library",
            words = {"vim%.uv"}
        }, {
            path = "snacks.nvim",
            words = {"Snacks"}
        }, {
            path = "lazy.nvim",
            words = {"LazyVim"}
        }}
    },
    optional = true
}, {
    "saghen/blink.cmp",
    opts = {
        sources = {
            -- add lazydev to your completion providers
            default = {"lazydev"},
            providers = {
                lazydev = {
                    name = "LazyDev",
                    module = "lazydev.integrations.blink",
                    score_offset = 100 -- show at a higher priority than lsp
                }
            }
        }
    }
}, -- Markdown
{
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {"nvim-treesitter/nvim-treesitter", "echasnovski/mini.icons"},
    opts = {},
    optional = true
}, {
    "saghen/blink.cmp",
    opts = {
        sources = {
            default = {"markdown"},
            providers = {
                markdown = {
                    name = "RenderMarkdown",
                    module = "render-markdown.integ.blink",
                    fallbacks = {"lsp"}
                }
            }
        }
    }
}, -- Support copilot as source
{
    "saghen/blink.cmp",
    dependencies = {"fang2hou/blink-copilot"},
    opts = {
        sources = {
            default = {"copilot"},
            providers = {
                copilot = {
                    name = "copilot",
                    module = "blink-copilot",
                    score_offset = 100,
                    async = true
                }
            }
        }
    }
}, -- Refactoring
{
    "folke/which-key.nvim",
    optional = true,
    opts = {
        spec = {{
            "<leader>d",
            group = "debug"
        }, {
            "<leader>r",
            group = "refactoring",
            icon = ""
        }}
    }
}, -- The Refactoring library based off the Refactoring book by Martin Fowler
{
    "ThePrimeagen/refactoring.nvim",
    vscode = true,
    dependencies = {{
        "nvim-lua/plenary.nvim",
        vscode = true
    }, {"nvim-treesitter/nvim-treesitter"}},
    keys = {{
        "<leader>rm",
        function()
            require("refactoring").select_refactor {
                show_success_message = true
            }
        end,
        mode = {"n", "v"},
        desc = "Refactoring Menu"
    }, {
        "<leader>re",
        function()
            require("refactoring").refactor "Extract Function"
        end,
        desc = "Extract",
        mode = "x"
    }, {
        "<leader>rf",
        function()
            require("refactoring").refactor "Extract Function To File"
        end,
        desc = "Extract to file",
        mode = "x"
    }, {
        "<leader>rv",
        function()
            require("refactoring").refactor "Extract Variable"
        end,
        desc = "Extract variable",
        mode = "x"
    }, {
        "<leader>ri",
        function()
            require("refactoring").refactor "Inline Variable"
        end,
        desc = "Inline variable",
        mode = {"n", "x"}
    }, {
        "<leader>rI",
        function()
            require("refactoring").refactor "Inline Function"
        end,
        desc = "Inline function",
        mode = {"n"}
    }, {
        "<leader>rb",
        function()
            require("refactoring").refactor "Extract Block"
        end,
        desc = "Extract block"
    }, {
        "<leader>rB",
        function()
            require("refactoring").refactor "Extract Block To File"
        end,
        desc = "Extract block to file"
    }, -- Debug variable
    {
        "<leader>dv",
        function()
            require("refactoring").debug.print_var {
                show_success_message = true,
                below = true
            }
        end,
        mode = {"n", "x"},
        desc = "Print below variables"
    }, {
        "<leader>dV",
        function()
            require("refactoring").debug.print_var {
                show_success_message = true,
                below = false
            }
        end,
        mode = {"n", "x"},
        desc = "Print above variables"
    }, -- Clean up debugging
    {
        "<leader>dc",
        function()
            require("refactoring").debug.cleanup {
                force = true,
                show_success_message = true
            }
        end,
        desc = "Clear debugging"
    }},
    opts = {
        prompt_func_return_type = {
            go = false,
            java = false,

            cpp = false,
            c = false,
            h = false,
            hpp = false,
            cxx = false
        },
        prompt_func_param_type = {
            go = false,
            java = false,

            cpp = false,
            c = false,
            h = false,
            hpp = false,
            cxx = false
        },
        printf_statements = {},
        print_var_statements = {}
    }
}, -- Code comment
{
    "folke/ts-comments.nvim",
    opts = {},
    event = "VeryLazy"
}, -- Learn those tips from LazyVim
-- Auto pairs
{
    "echasnovski/mini.pairs",
    event = "VeryLazy",
    opts = {}
}, -- Extend and create a/i textobjects
{
    "echasnovski/mini.ai",
    event = "VeryLazy",
    opts = function()
        local ai = require "mini.ai"
        return {
            n_lines = 500,
            custom_textobjects = {
                o = ai.gen_spec.treesitter { -- code block
                    a = {"@block.outer", "@conditional.outer", "@loop.outer"},
                    i = {"@block.inner", "@conditional.inner", "@loop.inner"}
                },
                f = ai.gen_spec.treesitter {
                    a = "@function.outer",
                    i = "@function.inner"
                }, -- function
                c = ai.gen_spec.treesitter {
                    a = "@class.outer",
                    i = "@class.inner"
                }, -- class
                t = {"<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$"}, -- tags
                d = {"%f[%d]%d+"}, -- digits
                e = { -- Word with case
                {"%u[%l%d]+%f[^%l%d]", "%f[%S][%l%d]+%f[^%l%d]", "%f[%P][%l%d]+%f[^%l%d]", "^[%l%d]+%f[^%l%d]"},
                "^().*()$"},
                u = ai.gen_spec.function_call(), -- u for "Usage"
                U = ai.gen_spec.function_call {
                    name_pattern = "[%w_]"
                } -- without dot in function name
            }
        }
    end,
    -- Use gs for surround as `s` is used by flash
    {
        "echasnovski/mini.surround",
        vscode = true,
        opts = {
            mappings = {
                add = "gsa", -- Add surrounding in Normal and Visual modes
                delete = "gsd", -- Delete surrounding
                find = "gsf", -- Find surrounding (to the right)
                find_left = "gsF", -- Find surrounding (to the left)
                highlight = "gsh", -- Highlight surrounding
                replace = "gsr", -- Replace surrounding
                update_n_lines = "gsn" -- Update `n_lines`
            }
        }
    }, -- A better annotation generator. Supports multiple languages and annotation conventions.
    -- <C-n> to jump to next annotation, <C-p> to jump to previous annotation
    {
        "danymat/neogen",
        dependencies = "nvim-treesitter/nvim-treesitter",
        opts = {
            enabled = true
        },
        cmd = "Neogen",
        vscode = true,
        keys = {{
            "<leader>ci",
            "<cmd>Neogen<cr>",
            desc = "Neogen: Annotation generator"
        }}
    }
}}
