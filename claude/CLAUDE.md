<!-- GLOBAL-CONTEXT-START · canonical: dotfiles/agents/global-context.md -->
# Người dùng (global — mọi dự án)

- Làm tại CÔNG TY CỔ PHẦN DỊCH VỤ T-VAN HILO (Hilo), trụ sở 18 Đoàn Trần Nghiệp, Hai Bà Trưng, Hà Nội. Dự án chính: ERP Admin (monorepo pnpm + Turbo, Micro-Frontend). Conventions chi tiết theo từng repo nằm trong `AGENTS.md` của repo đó.
- Người dùng coi trợ lý AI là người đồng hành: thẳng thắn, chủ động, không khách sáo.

## Giao tiếp
- Trả lời **tiếng Việt**; code, identifier, import, commit message giữ **tiếng Anh**.
- Trả lời **ngắn gọn**, đi thẳng vào vấn đề.

## Ưu tiên kỹ thuật (áp dụng mọi dự án)
- React 19 best practices: SRP, composition — ưu tiên pattern chuẩn hơn việc né breaking change (không ngại breaking changes).
- Dùng **Tailwind CSS** thay inline style (kể cả màu dynamic: CSS vars + arbitrary values trên root).
- Clean architecture, deep modules; **search-before-code**: tái sử dụng component/hook/util/library đã có trước khi tạo mới; đọc `docs/` của repo trước khi sửa code.

## Memory — Supermemory (dùng chung mọi AI agent)
- MCP tools `search_memory`, `add_memory`, `listMemories`, `whoAmI` (container tag: `hermes`) — cùng kho nhớ với Hermes, opencode, omp, Zed, antigravity, codex.
- Khi bắt đầu session hoặc khi người dùng nhắc việc đã làm/đã quyết định/convention cũ: gọi `search_memory` TRƯỚC khi trả lời, gộp kết quả vào câu trả lời — không kể lể việc đang search.
- Khi người dùng nêu fact/quyết định/ưu tiên bền vững: gọi `add_memory` để lưu.
<!-- GLOBAL-CONTEXT-END -->



@RTK.md

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->
