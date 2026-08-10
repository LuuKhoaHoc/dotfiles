BE/PO feature request: tạo issue MỚI, chỉ tách khi ready-for-human/BE-decision (rule gộp đầy đủ: user profile).
§
cuongt(id=10)=Finance + HR employee-scoped specs; QuyCN(id=31)=Product + HR attendance-sheet-scoped specs.
§
ERP repo: ~/Dev-Work/Hilo/erp-admin (clone dùng chung) — fetch origin all branches TRƯỚC khi tin status -sb (ref stale); sau pull lớn rebuild dist @hilo/shared+ui trước typecheck; branch-read git show origin/<b>:<path>; worktrees ~/Dev-Work/Hilo/worktrees/; có .codegraph/ (init 08/2026) — codegraph_explore MCP projectPath=repo root trước grep.
§
BE/API mới: gọi curl trước, ghi status/trace vào issue, không lưu token.
§
ERP API: ApiResponse<T> — T=item|item[] (array ở .data), pagination ở meta.pagination; cấm wrapper/normalize (docs/solutions 2026-08-05).
§
search_files(target='files') dùng GLOB — '|' trả 0 match; đôi khi IO error os error 3 trên apps/*/src → fallback grep -r terminal; MCP list_issues đôi khi trả toàn bộ → filter local.
§
omp=oh-my-pi: ~/.bun/bin/omp, ~/.omp/agent (secret trong models.yml/mcp.json → sync qua dotfiles/omp/sync-omp.sh strip <redacted>); Win 9router :20128.
§
MCP: gitlab=node.exe; GitLab PAT + GWS secret trong .env.
§
Hermes: 8 Google Workspace MCP (oauth; re-auth ~/gws_mcp_oauth.py; hermes mcp login KHÔNG chạy).
§
Employee MFE issue labels: employee,feature,frontend,priority::medium,ready-for-agent (MFE::hr chỉ hr-dashboard).
§
pnpm/corepack hỏng → node file JS thật (.bin shim là bash: eslint=eslint/bin/eslint.js, prettier=prettier/bin/prettier.cjs);
§
antigravity IDE chạy song song trên erp-admin — file có thể bị user sửa CHỦ Ý giữa chừng; diff lạ đừng restore vội, đọc kỹ + hỏi user.
§
dotfiles repo: ~/Dev-Work/dotfiles (github LuuKhoaHoc/dotfiles, PUBLIC — cấm secret; config per-OS). Sync: hermes/opencode/omp sync-*.sh; migrate: hermes/migrate-to-linux.sh → ~/hermes-migration.
§
User kiểm soát merge/commit ('khoan merge'/'khoan commit' = dừng hẳn). Cấm set merge_when_pipeline_succeeds khi pipeline đã success (merge ngay).
§
erp-admin FE: i18n eventType dùng RAW dotted keys (không normalize); placeholder chuẩn = placeholder:text-muted-foreground (placeholder:text-text-* đậm gây nhầm value).