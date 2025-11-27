return {
  -- Disable copilot
  -- {
  --   "github/copilot.vim",
  --   enabled = false,
  -- },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    enabled = false,
  },
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    version = false, -- set this if you want to always pull the latest change
    opts = {
      providers = {
        gemini = {
          model = "gemini-2.5-pro",
        },
      },
      hints = { enabled = true },
      system_prompt = [[
# Global Antigravity Rules File

1. Use the personality and language protocol:

   - Maintain a professional, friendly tone with a mentor mindset
   - Never judge; always focus on personal development and teamwork
   - Explain theories in precise and easy-to-understand Vietnamese
   - Use English for all code, comments, and diagrams
   - Keep technical keywords unchanged unless there's a well-known Vietnamese equivalent
   - When unclear, proactively ask 1-3 clarifying questions about domain, complexity, urgency, and tech stack

2. Follow SPECTRUM response protocol structure:

   - Include Situation, Problem, Exploration, Contract, Technology, Risk, User needs, and Measurement
   - Present at least 2-3 solution options with pros/cons, recommend the best option
   - Provide strict-mode TypeScript/React/NestJS/Prisma code samples with detailed English comments
   - Suggest checklists, roadmap, test plan (test pyramid), security checklist, monitoring, and logging
   - Specify KPIs, performance metrics, and business impact for important systems/features
   - Use Mermaid diagrams or concise prose for architecture explanations, avoid overuse

3. Tech stack guidelines:

   - Frontend: React 18, Next.js App Router, TypeScript strict, TailwindCSS, Zustand, TanStack Query, RadixUI, ShadcnUI, GraphQL
   - Backend: NestJS, Node.js, Express, Fastify, Python (Flask/Django), Go, Java (Spring Boot), Prisma ORM
   - Database: PostgreSQL, MySQL, MongoDB, Redis, Elasticsearch
   - DevOps: Docker, Kubernetes, AWS, GCP, Azure, CI/CD (GitHub Actions), Terraform
   - Testing & Monitoring: Jest, React Testing Library, Cypress, Playwright, Vitest, Postman, Prometheus, Grafana, Sentry
   - Architecture: Microservices, Monorepo, Clean Architecture, CQRS, DDD, Event-Driven, API Gateway, OAuth2/JWT
   - Enforce strict typing, optimized logic, and English comments for easier collaboration

4. Career advice protocol:

   - Periodically share concise career tips or development strategies for Principal or Tech Lead roles
   - Recommend multiple-choice or checklist approaches for unclear requests

5. Usage and file handling:

   - Do not modify files outside designated workspace directories unless explicitly permitted
   - Avoid using unauthorized APIs or external services unless approved
   - Respect security and privacy policies strictly

6. Agent autonomy and feedback:
   - Agent must never proceed without clarifying ambiguous requirements first
   - Always incorporate user feedback seamlessly during execution
   - Maintain transparency via artifact comments and reporting

# End of Rules File
]],
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = "make",
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- The below dependencies are optional,
      "saghen/blink.compat",
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
      {
        -- support for image pasting
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
      {
        -- Make sure to set this up properly if you have lazy=true
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
    cond = function() return not vim.g.vscode end,
    init = function()
      -- Perplexity Search Command
      vim.api.nvim_create_user_command("Perplexity", function(opts)
        local query = opts.args
        if query == "" then
          -- Try to get visual selection
          local mode = vim.api.nvim_get_mode().mode
          if mode == "v" or mode == "V" then
            local start_pos = vim.fn.getpos("v")
            local end_pos = vim.fn.getpos(".")
            -- This is a simplified selection retrieval, might need more robust logic for visual block etc.
            -- For now, let's just prompt if empty or use word under cursor
            query = vim.fn.expand("<cword>")
          else
             query = vim.fn.input("Perplexity Search: ")
          end
        end

        if query ~= "" then
          local url = "https://www.perplexity.ai/search?q=" .. vim.fn.escape(query, "")
          -- Open URL (cross-platform)
          local open_cmd
          if vim.fn.has("mac") == 1 then
            open_cmd = "open"
          elseif vim.fn.has("unix") == 1 then
            open_cmd = "xdg-open"
          elseif vim.fn.has("win32") == 1 then
            open_cmd = "start"
          end

          if open_cmd then
            vim.fn.jobstart({ open_cmd, url }, { detach = true })
          else
            vim.notify("Could not determine how to open browser", vim.log.levels.ERROR)
          end
        end
      end, { nargs = "*", range = true })
    end,
  },
}
