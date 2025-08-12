local prompts = {
  -- Code Understanding
  Explain          = "Explain the following code step-by-step",
  Review           = "Review the following code and suggest improvements",
  Documentation    = "Write detailed documentation for the following code",

  -- Code Modification
  Refactor         = "Refactor the following code to improve clarity and maintainability",
  FixCode          = "Fix the following code so it works as intended",
  Optimize         = "Suggest performance optimizations for the following code",
  SecurityAudit    = "Check for security vulnerabilities in the following code",

  -- Testing
  Tests            = "Explain the code and then generate unit tests for it",

  -- API Docs
  SwaggerApiDocs   = "Generate Swagger API documentation for the following code",
  SwaggerJsDocs    = "Generate Swagger-style JSDoc comments for the following code",

  -- Text / Writing
  BetterNaming     = "Suggest better variable and function names for the following code",
  Summarize        = "Summarize the following text",
  Spelling         = "Correct grammar and spelling errors in the following text",
  Wording          = "Improve grammar and wording in the following text",
  Concise          = "Rewrite the following text to be more concise",

  -- Special context
  CommitMsg        = "Write a commit message for the following git diff: #gitdiff",
  ExplainLog       = "Explain the cause of the following error log and suggest a fix",
  RegexHelper      = "Create a regex pattern to match the following requirement",
  TransToVi        = "Translate the following text to Vietnamese",

  -- System personal
  Yarrr            = {
    system_prompt = "You are fascinated by pirates, so please respond in pirate speak."
  },
  NiceInstructions = {
    system_prompt = 'You are a nice coding tutor, so please respond in a friendly and helpful manner. '
        .. ((default_prompts and default_prompts.COPILOT_BASE and default_prompts.COPILOT_BASE.system_prompt) or ""),
  },
  StrictReviewer   = {
    system_prompt = "You are a strict senior developer focused on clean, performant, and secure code."
  },
  FastFixer        = {
    system_prompt = "You fix issues quickly with minimal changes while preserving functionality."
  }
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
      { "<leader>af", "<cmd>CopilotChatFix<cr>",    desc = "CopilotChat - Fix Diagnostic" },
      -- Clear buffer and chat history
      { "<leader>al", "<cmd>CopilotChatReset<cr>",  desc = "CopilotChat - Clear buffer and chat history" },
      -- Toggle Copilot Chat Vsplit
      { "<leader>av", "<cmd>CopilotChatToggle<cr>", desc = "CopilotChat - Toggle" },
      -- Copilot Chat Models
      { "<leader>a?", "<cmd>CopilotChatModels<cr>", desc = "CopilotChat - Select Models" },
      -- Copilot Chat Agents
      { "<leader>aa", "<cmd>CopilotChatAgents<cr>", desc = "CopilotChat - Select Agents" },
    },
  },
}
