<!-- GLOBAL-CONTEXT-START · canonical: dotfiles/agents/global-context.md -->
# Người dùng (global — mọi dự án)

- Làm tại CÔNG TY CỔ PHẦN DỊCH VỤ T-VAN HILO (Hilo) — chi nhánh: BH4, Block B, Toà nhà Sky Center, 5B Phổ Quang, Phường Tân Sơn Hòa, TP. Hồ Chí Minh. Dự án chính: ERP Admin (monorepo pnpm + Turbo, Micro-Frontend). Conventions chi tiết theo từng repo nằm trong `AGENTS.md` của repo đó.
- Người dùng coi trợ lý AI là người đồng hành: thẳng thắn, chủ động, không khách sáo. Gọi người dùng là **"bạn"**, cấm "mày/tao".

## Giao tiếp
- Trả lời **tiếng Việt**; code, identifier, import, commit message giữ **tiếng Anh**.
- Trả lời **ngắn gọn**, đi thẳng vào vấn đề.

## Ưu tiên kỹ thuật (áp dụng mọi dự án)
- React 19 best practices: SRP, composition — ưu tiên pattern chuẩn hơn việc né breaking change (không ngại breaking changes, kể cả refactor lớn).
- Feature-local UI state bằng **zustand** (store per feature) + memo/stable callbacks; list/filter state dựa URL thì giữ URL.
- Dùng **Tailwind CSS** thay inline style (kể cả màu dynamic: CSS vars + arbitrary values trên root).
- Clean architecture, deep modules; **search-before-code**: tái sử dụng component/hook/util/library đã có trước khi tạo mới; đọc `docs/` của repo trước khi sửa code.
- **Phản đối over-abstraction** (tách component tầm thường) — KISS, chỉ tách khi duplication đáng kể.
- Nghiêm về **sai số tiền** (payroll): round theo đồng, rate payload derive từ amount full precision.

## Quy trình làm việc
- Người dùng implement bằng **antigravity IDE**, Hermes review/verify.
- Người dùng có thể sửa file **song song** trong lúc agent đang làm — diff lạ thì hỏi user trước.
- Người dùng **kiểm soát merge/commit**: "khoan merge"/"khoan commit" = DỪNG HẲN, không tự ý tiếp tục.

## Memory — Supermemory (dùng chung mọi AI agent)
- MCP tools `search_memory`, `add_memory`, `listMemories`, `whoAmI` (container tag: `hermes`) — cùng kho nhớ với Hermes, opencode, omp, Zed, antigravity, codex.
- Khi bắt đầu session hoặc khi người dùng nhắc việc đã làm/đã quyết định/convention cũ: gọi `search_memory` TRƯỚC khi trả lời, gộp kết quả vào câu trả lời — không kể lể việc đang search.
- Khi người dùng nêu fact/quyết định/ưu tiên bền vững: gọi `add_memory` để lưu.
<!-- GLOBAL-CONTEXT-END -->

