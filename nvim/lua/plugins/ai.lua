local prompts = {
  -- Code Modification
  Refactor = "Refactor the following code to improve clarity and maintainability {selection}",
  ConvertToType = "Convert the following code to type or interface {selection}",
  AddComments = "Add detailed comments to explain the following code {selection}",
  Optimize = "Optimize the following code for better performance {selection}",
  FindBugs = "Analyze the following code and identify any potential bugs or issues {selection}",

  -- Text / Writing
  BetterNaming = "Suggest better variable and function names for the following code {selection}",
  Wording = "Improve grammar and wording in the following text {selection}",
  Concise = "Rewrite the following text to be more concise {selection}",
  Document = "Generate documentation for the following code {selection}",

  -- Testing
  UnitTests = "Write unit tests for the following code using a popular testing framework {selection}",
  TestCases = "Suggest edge cases and test scenarios for the following code {selection}",

  -- Special context
  TransToVi =
  "Please accurately translate the following text into Vietnamese, preserving its meaning and context: {selection}",
  TransToEn =
  "Please accurately translate the following text into English, preserving its meaning and context: {selection}",
  ExplainLikeIm5 = "Explain the following concept like I'm 5 years old by Vietnamese except technical word {selection}",
  ExplainDetail =
  "Explain the selected code in clear, step-by-step detail. For each line or block, state its purpose, inputs/outputs, data flow, side effects, and any potential bugs or edge cases. Suggest improvements and include a brief example if helpful. Code: {selection}",
}

-- Setup AI with CopilotChat
return {
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>a",  group = "ai" },
        { "<leader>gm", group = "Copilot Chat" },
      },
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    opts = {
      file_types = { "markdown", "copilot-chat" },
    },
    ft = { "markdown", "copilot-chat" },
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "main",
    dependencies = {
      { "github/copilot.vim" },
      { "nvim-lua/plenary.nvim", branch = "master" },
    },
    build = "make tiktoken", -- Only on MacOS or Linux
    opts = {
      question_header = "## User ",
      answer_header = "## Copilot ",
      error_header = "## Error ",
      prompts = prompts,
      language = "vi",
      window = {
        width = 0.4,                                               -- Percentage of the editor width
        height = 0.5,                                              -- Percentage of the editor height
        border = 'rounded',                                        -- 'single', 'double', 'rounded', 'solid'
        title = '🤖 AI Assistant',
        zindex = 100,                                              -- Ensure window stays on top
        relativenumber = true,                                     -- Show relative line numbers
        winhighlight = "Normal:Normal,FloatBorder:DiagnosticInfo", -- Highlight groups
      },
      mappings = {
        -- Use tab for completion
        complete = {
          detail = "Use @<Tab> or /<Tab> for options.",
          insert = "<Tab>",
        },
        -- Close the chat
        close = {
          normal = "q",
          insert = "<C-c>",
        },
        -- Reset the chat buffer
        reset = {
          normal = "<C-x>",
          insert = "<C-x>",
        },
        -- Submit the prompt to Copilot
        submit_prompt = {
          normal = "<CR>",
          insert = "<C-CR>",
        },
        -- Accept the diff
        accept_diff = {
          normal = "<C-y>",
          insert = "<C-y>",
        },
        -- Show help
        show_help = {
          normal = "g?",
        },
      },
    },
    keys = {
      -- Show prompts actions with telescope
      {
        "<leader>ap",
        function()
          require("CopilotChat").select_prompt {
            context = {
              "buffers",
            },
          }
        end,
        desc = "CopilotChat - Prompt actions",
      },
      {
        "<leader>ap",
        function()
          require("CopilotChat").select_prompt()
        end,
        mode = "x",
        desc = "CopilotChat - Prompt actions",
      },
      -- Generate commit message based on the git diff
      {
        "<leader>am",
        "<cmd>CopilotChatCommit<cr>",
        desc = "CopilotChat - Generate commit message for all changes",
      },
      -- Fix the issue with diagnostic
      { "<leader>af", "<cmd>CopilotChatFix<cr>",            desc = "CopilotChat - Fix Diagnostic" },
      -- Clear buffer and chat history
      { "<leader>al", "<cmd>CopilotChatReset<cr>",          desc = "CopilotChat - Clear buffer and chat history" },
      -- Toggle Copilot Chat Vsplit
      { "<leader>av", "<cmd>CopilotChatToggle<cr>",         desc = "CopilotChat - Toggle" },
      -- Copilot Chat Models
      { "<leader>a?", "<cmd>CopilotChatModels<cr>",         desc = "CopilotChat - Select Models" },
      -- Copilot Chat Agents
      { "<leader>aa", "<cmd>CopilotChatAgents<cr>",         desc = "CopilotChat - Select Agents" },
      -- Generate unit tests for the current file
      { "<leader>at", "<cmd>CopilotChatUnitTests<cr>",      desc = "CopilotChat - Generate Unit Test" },
      -- Explain code like I'm 5
      { "<leader>ae5", "<cmd>CopilotChatExplainLikeIm5<cr>", desc = "CopilotChat - Explain code like I'm 5" },
      -- Explain code with detail
      { "<leader>ad", "<cmd>CopilotChatExplainDetail<cr>",  desc = "CopilotChat - Explain code with detail" },
      -- Quick chat
      {
        "<leader>ae",
        function()
          local input = vim.fn.input("Quick chat: ")
          if input ~= "" then
            require("CopilotChat").ask(input)
          end
        end,
        desc = "CopilotChat - Quick chat",
      },
    },
  },
}
