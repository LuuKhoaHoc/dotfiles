-- ===== Custom prompts for CopilotChat =====
local prompts = {
  -- Code Modification
  Refactor = [[Refactor the following code to improve clarity and maintainability while preserving behavior.
Output format:
1) Problem summary (Vietnamese)
2) Explanation of changes (Vietnamese, bullets, keep technical terms in English)
3) Unified diff (English code)
Code:
{selection}]],

  ConvertToType = [[Convert the following code to proper TypeScript types or interfaces (prefer strict typing, avoid any).
Output: Explanation (Vietnamese) -> Code/types (English).
Code:
{selection}]],

  AddComments = [[Add comments/JSDoc/TSDoc to explain the following code (write comments in English).
Output: Key points explanation (Vietnamese) -> Code with comments (English).
Code:
{selection}]],

  Optimize = [[Optimize performance for the following code (avoid unnecessary re-renders, optimize data fetching/state).
Output format:
1) Current performance issues (Vietnamese)
2) Optimization suggestions (Vietnamese, bullets)
3) Unified diff (English)
Code:
{selection}]],

  FindBugs = [[Analyze the following code and identify potential bugs/issues (logic, edge cases, types, async, security).
Output format:
1) Bug/issue summary (Vietnamese)
2) Root cause and edge cases (Vietnamese)
3) Unified diff to fix (English)
4) How to verify (Vietnamese + English commands if needed)
Code:
{selection}]],

  -- Text / Writing
  BetterNaming = [[Suggest better variable/function names for the following code (clear, consistent, following conventions).
Output format:
1) Naming criteria explanation (Vietnamese)
2) Table: oldName -> newName (English)
3) (Optional) Unified diff if needed (English)
Code:
{selection}]],

  Wording = [[Improve grammar and wording for the following text.
Respond in Vietnamese, keep technical terms in English.
Text:
{selection}]],

  Concise = [[Rewrite the following text to be more concise while preserving meaning.
Respond in Vietnamese, keep technical terms in English.
Text:
{selection}]],

  Document = [[Generate documentation for the following code (e.g., README section or module docs).
Output:
- Overview explanation in Vietnamese
- Code examples/signatures in English.
Code:
{selection}]],

  -- Testing
  UnitTests = [[Write unit tests for the following code (prefer Jest + React Testing Library for UI).
Output format:
1) Test strategy explanation (Vietnamese)
2) List of main test cases (Vietnamese)
3) Test code (English)
Code:
{selection}]],

  TestCases = [[Suggest edge cases and test scenarios for the following code.
Respond in Vietnamese, use bullet points, specify input, expected output, and failure modes.
Code:
{selection}]],

  -- Special context
  TransToVi = [[Accurately translate the following text into Vietnamese, preserving meaning and context:
{selection}]],

  TransToEn = [[Accurately translate the following text into English, preserving meaning and context:
{selection}]],

  ExplainLikeIm5 = [[Explain the following concept as if to a 5-year-old, in Vietnamese, but keep technical words in English.
Content:
{selection}]],

  ExplainDetail = [[Explain the selected code in detail:
- Purpose of each block
- Inputs/outputs, data flow, side effects
- Potential bugs/edge cases
- Improvement suggestions (prefer minimal changes)
Output: Explanation (Vietnamese) -> Code examples (English if needed).
Code:
{selection}]],

  -- GraphQL
  GraphQLSchema = [[Create or improve GraphQL schema/types for the following code.
Output format:
1) Structure and relationships explanation (Vietnamese)
2) Schema/types code (English)
3) Example queries/mutations if needed (English)
Code:
{selection}]],

  GraphQLResolver = [[Write resolver for the following GraphQL schema (prefer NestJS GraphQL for backend).
Output format:
1) Data flow explanation (Vietnamese)
2) Resolver code with proper typing (English)
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
      system_prompt = [[
Bạn là AI pair-programmer của tôi trong Neovim, hành động như Senior Frontend/Full-stack Engineer tập trung vào maintainability và product UX.

## Ngôn ngữ
- Luôn trả lời bằng TIẾNG VIỆT cho phần giải thích, phân tích, hướng dẫn.
- CHỈ dùng TIẾNG ANH cho:
  - Technical terms (React hooks, state, props, hydration, memoization, middleware, v.v.)
  - Tên thư viện/framework (React, Next.js, TailwindCSS, React Query, Redux, Jest, v.v.)
  - Tên hàm/biến/types, tên API, error messages
  - Toàn bộ code và unified diff.

## Format trả lời mặc định
Luôn cố gắng giữ đúng thứ tự sau (trừ khi user yêu cầu khác):
1) Tóm tắt nhanh vấn đề (1-2 câu, VI)
2) Giải thích nguyên nhân + hướng giải quyết (VI, dùng bullets)
3) Đề xuất thay đổi chính và trade-offs (VI, bullets)
4) Unified diff hoặc code block (EN)
5) Cách verify (VI + commands/steps EN nếu cần)

Nếu không đủ context quan trọng (file khác, API contract, error log), hãy:
- Hỏi lại tối đa 3 câu ngắn gọn
- Sau đó đưa ra 1-2 phương án hợp lý nhất, nêu rõ assumptions.

## Stack & ưu tiên kỹ thuật
- TypeScript strict mindset: tránh `any`, ưu tiên type rõ ràng, type guards.
- React / Next.js (ưu tiên App Router):
  - Semantic HTML + a11y (labels, aria, keyboard navigation).
  - Hạn chế re-render không cần thiết, components nhỏ gọn, tách data-fetching khỏi presentation.
- NestJS (backend):
  - Modules, Controllers, Services pattern.
  - DTOs với class-validator, Swagger decorators.
  - Exception filters, Guards, Interceptors khi cần.
- GraphQL:
  - Code-first approach với NestJS.
  - Proper typing cho resolvers, input types, object types.
- Data/state:
  - React Query cho server state; Redux/RTK cho global client state khi cần.
  - Loading / error / empty states rõ ràng.
- UI/UX:
  - TailwindCSS với tokens nhất quán.
  - Trải nghiệm mượt, feedback rõ ràng khi loading, error, submit, v.v.
- Performance & security:
  - Ưu tiên correctness > clarity > minimal changes > performance.
  - Tránh over-engineering; thay đổi tối thiểu để dễ review/merge.

## Quy tắc output trong terminal
- Không dump toàn bộ file lớn; chỉ hiển thị phần code liên quan, dùng comment kiểu `// ...` cho phần bỏ qua.
- Khi sửa code, mặc định ưu tiên unified diff (EN). Chỉ trả full file khi user yêu cầu rõ ràng.
- Sử dụng Markdown, code fenced blocks với language tags (ts, tsx, js, jsx, bash, v.v.).
      ]],

      question_header = "## User ",
      answer_header = "## Copilot ",
      error_header = "## Error ",

      prompts = prompts,
      language = "vi",

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
      { "<leader>af", "<cmd>CopilotChatFix<cr>",           desc = "CopilotChat - Fix Diagnostic" },
      { "<leader>al", "<cmd>CopilotChatReset<cr>",         desc = "CopilotChat - Clear buffer and chat history" },
      { "<leader>av", "<cmd>CopilotChatToggle<cr>",        desc = "CopilotChat - Toggle" },
      { "<leader>a?", "<cmd>CopilotChatModels<cr>",        desc = "CopilotChat - Select Models" },
      { "<leader>aa", "<cmd>CopilotChatAgents<cr>",        desc = "CopilotChat - Select Agents" },
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
