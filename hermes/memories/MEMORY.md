BE/PO feature request → tạo issue MỚI; chỉ tách khi ready-for-human/BE-decision. BE/API mới: curl trước, ghi status vào issue.
§
cuongt(10)=Finance+HR employee-scoped+request-management; QuyCN(31)=Product+HR attendance+shell/apps-dashboard; luukhoahoc shared/arch; PO quyết khi phân bug.
§
ERP API: ApiResponse<T> — T=item|item[] (.data), pagination meta.pagination; cấm wrapper/normalize.
§
verify MR: pnpm --filter <pkg> exec vitest (exec --filter sai); worktree: install+build-infra riêng từng cái (thiếu→TS2307 @hilo/*); glab issue create: -R <repo> (--project unknown flag), --milestone nhận title.
§
Employee MFE labels: employee,feature,frontend,priority::medium,ready-for-agent (MFE::hr→hr-dashboard).
§
antigravity chạy song song — file user sửa giữa chừng; diff lạ hỏi user.
§
dotfiles: ~/Dev-Work/dotfiles PUBLIC — cấm secret; sync sync-*.sh.
§
User kiểm soát merge/commit ('khoan merge'/'khoan commit'=dừng); cấm merge_when_pipeline_succeeds khi pipeline success.
§
Curator patch được khi frontmatter author=hermes-curator (vd erp-admin-ui-mr-review, agent-memory); còn lại user-owned → từ chối, cần 'hermes curator adopt'.
§
Hermes gateway: TG @picoclaw_leo_bot (1082824633); force_ipv4=true (VN IPv6 hỏng).
§
supermemory: store→Notes, entry auto hay hỏng→verify, lưu EN LLM-proof.
§
AGENTS.md: canonical = dotfiles/agents/global-context.md; ~/.local/bin/agents-sync push|pull (6 harness: opencode, omp, zed, gemini, codex, claude). Skills mirror hermes = copy tay, KHÔNG symlink (agents-sync không sync skills).
§
MR re-review: fetch refs/merge-requests/<iid>/head so head_sha; head không đổi → user muốn MR khác cùng tác giả (list by author_username).
§
CRM authz (BE chốt 08/2026): /crm/* cần context chọn (403 CRM-403-004); GET /auth/crm/contexts+select-context kể cả 1 context; CRM_SYSTEM_ADMIN clone/assign system/template (docs cũ ghi ngược).
§
User định build ERP cá nhân từ kinh nghiệm (không copy code công ty), NDA → tách dữ liệu công ty/cá nhân.
§
Azure VM 9router-vm (khoahoc, key ~/Downloads/9router-key.pem, IP DYNAMIC chưa pin): 9router:20128+agentmemory:3111+cloudflared systemd; router/mem.luukhoahoc.me; configs local trỏ cloud; ~/.9router DB clone nguồn provider.