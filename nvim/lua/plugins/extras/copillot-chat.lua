-- ===== Custom prompts for CopilotChat =====
local prompts = {
  -- Code Modification
  Refactor = [[Refactor the following code to improve clarity and maintainability while preserving behavior.
Output format:
1) Problem summary
2) Explanation of changes
3) Unified diff
Code:
{selection}]],

  ConvertToType =
  [[Convert the following code to proper TypeScript types or interfaces (prefer strict typing, avoid any).
Output: Explanation -> Code/types.
Code:
{selection}]],

  AddComments = [[Add comments/JSDoc/TSDoc to explain the following code.
Output: Key points explanation -> Code with comments.
Code:
{selection}]],

  Optimize = [[Optimize performance for the following code (avoid unnecessary re-renders, optimize data fetching/state).
Output format:
1) Current performance issues
2) Optimization suggestions (bullets)
3) Unified diff
Code:
{selection}]],

  FindBugs = [[Analyze the following code and identify potential bugs/issues (logic, edge cases, types, async, security).
Output format:
1) Bug/issue summary
2) Root cause and edge cases
3) Unified diff to fix
4) How to verify (commands if needed)
Code:
{selection}]],

  -- Text / Writing
  BetterNaming =
  [[Suggest better variable/function names for the following code (clear, consistent, following conventions).
Output format:
1) Naming criteria explanation
2) Table: oldName -> newName
3) (Optional) Unified diff if needed
Code:
{selection}]],

  Wording = [[Improve grammar and wording for the following text.
Respond in English, keep technical terms accurate.
Text:
{selection}]],

  Concise = [[Rewrite the following text to be more concise while preserving meaning.
Respond in English.
Text:
{selection}]],

  Document = [[Generate documentation for the following code (e.g., README section or module docs).
Output:
- Overview explanation
- Code examples/signatures
Code:
{selection}]],

  -- Testing
  UnitTests = [[Write unit tests for the following code (prefer Jest + React Testing Library for UI).
Output format:
1) Test strategy explanation
2) List of main test cases
3) Test code
Code:
{selection}]],

  TestCases = [[Suggest edge cases and test scenarios for the following code.
Respond in English, use bullet points, specify input, expected output, and failure modes.
Code:
{selection}]],

  -- Special context
  TransToVi = [[Accurately translate the following text into Vietnamese, preserving meaning and context:
{selection}]],

  TransToEn = [[Accurately translate the following text into English, preserving meaning and context:
{selection}]],

  -- GraphQL
  GraphQLSchema = [[Create or improve GraphQL schema/types for the following code.
Output format:
1) Structure and relationships explanation
2) Schema/types code
3) Example queries/mutations if needed
Code:
{selection}]],

  GraphQLResolver = [[Write resolver for the following GraphQL schema (prefer NestJS GraphQL for backend).
Output format:
1) Data flow explanation
2) Resolver code with proper typing
Schema:
{selection}]],
}

-- ===== Setup AI with CopilotChat =====
return {
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>a", group = "ai" },
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
      -- Global system prompt cho mọi cuộc hội thoại
      model = "gemini-3-flash-preview",
      system_prompt = [[
Bạn là Senior pair-programmer trong Neovim (TypeScript/React/Next.js/NestJS).

## Quy tắc chung
- Giải thích EN và VI khi cần
- Unified diff (không full file), chỉ phần liên quan
- Hỏi nếu thiếu context → Assumptions rõ ràng

## Khi user hỏi GIẢI THÍCH
Format: Định nghĩa ngắn → Use cases → Trade-offs (nếu có)

## Khi user yêu cầu CODE/FIX
Format: Tóm tắt vấn đề → Unified diff → Verify steps
Ưu tiên: Correctness > Clarity > Minimal > Performance

## Khi user yêu cầu REVIEW
Tập trung: Type safety, a11y, performance bottlenecks, security

## Tech Stack Defaults
- TS strict, React (App Router), NestJS modules/DTOs
- TailwindCSS, React Query, GraphQL code-first
      ]],

      question_header = "## KhoaHoc ",
      answer_header = "## Copilot ",
      error_header = "## Error ",

      prompts = prompts,

      window = {
        width = 0.4,
        height = 0.5,
        border = "rounded",
        title = "🤖 AI Assistant",
        zindex = 100,
        relativenumber = true,
        winhighlight = "Normal:Normal,FloatBorder:DiagnosticInfo",
      },

      mappings = {
        complete = {
          detail = "Use @<Tab> or /<Tab> for options.",
          insert = "<Tab>",
        },
        close = {
          normal = "q",
          insert = "<C-c>",
        },
        reset = {
          normal = "<C-x>",
          insert = "<C-x>",
        },
        submit_prompt = {
          normal = "<CR>",
          insert = "<C-CR>",
        },
        accept_diff = {
          normal = "<C-y>",
          insert = "<C-y>",
        },
        show_help = {
          normal = "g?",
        },
      },
    },
    keys = {
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
      {
        "<leader>am",
        "<cmd>CopilotChatCommit<cr>",
        desc = "CopilotChat - Generate commit message for all changes",
      },
      { "<leader>af", "<cmd>CopilotChatFix<cr>",    desc = "CopilotChat - Fix Diagnostic" },
      { "<leader>al", "<cmd>CopilotChatReset<cr>",  desc = "CopilotChat - Clear buffer and chat history" },
      { "<leader>av", "<cmd>CopilotChatToggle<cr>", desc = "CopilotChat - Toggle" },
      { "<leader>a?", "<cmd>CopilotChatModels<cr>", desc = "CopilotChat - Select Models" },
      { "<leader>aa", "<cmd>CopilotChatAgents<cr>", desc = "CopilotChat - Select Agents" },
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
