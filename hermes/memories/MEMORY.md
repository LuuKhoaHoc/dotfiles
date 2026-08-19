BE/PO request → issue MỚI; chỉ tách khi ready-for-human/BE-decision. BE/API mới: curl trước ghi status.
§
cuongt(10)=Finance+HR emp-scoped+req-mgmt; QuyCN(31)=Product+HR attendance+shell/apps-dashboard; PO quyết khi phân bug.
§
ERP API: ApiResponse<T> — .data=item|item[], meta.pagination; cấm wrapper/normalize.
§
Issue lifecycle: close CHỈ khi milestone close/release deploy main; merge develop/UAT → set label status::done (không close). Delete/close thật → MCP update_issue. glab -R. --milestone=title. Release: bỏ shipped.
§
antigravity chạy song song — file user sửa giữa chừng; diff lạ hỏi user.
§
dotfiles PUBLIC — cấm secret.
§
User kiểm soát merge/commit ('khoan merge'/'khoan commit'=dừng); cấm merge_when_pipeline_succeeds.
§
Curator chỉ patch skill có frontmatter author=hermes-curator; user-owned → từ chối, cần 'hermes curator adopt'.
§
Hermes gateway: TG @picoclaw_leo_bot (1082824633); force_ipv4=true; cron deliver=all mới gửi TG.
§
agentmemory = mem.luukhoahoc.me; MCP ~/.local/bin/agentmemory-mcp; Hermes plugin+skills official; secret AGENTMEMORY_SECRET.
§
AGENTS.md canonical = dotfiles/agents/global-context.md; agents-sync push|pull; skills mirror copy tay.
§
MR review: worktree audit (KHÔNG checkout main), fetch head_sha, dev-rules audit script.
§
CRM authz: cần context (403 CRM-403-004); giá trị authz bị redact →*** (đọc hex khi nghi).
§
Partner = MFE RIÊNG 'partner' (label MFE::partner, BA chốt 14/08/26); luân chuyển+doanh thu×3 chưa spec; customers: chuyển dịch vụ.
§
Hermes projects: 1 project = 1 codebase; ĐÃ BỎ kanban (lag). Branch impl: feat/{issue}-{short}. Implementer: 9router free; default mimo-v2.5. Auto-review cron: MRs → reviewer GitLab.
§
hl.unbind≠o.bind → edit tiling.lua. SYNA0001 ≤3-finger. hotcorn → std::process::Command.
§
Shell: zsh. Orca = ADE chính Linux (thay Herdr/Zed/antigravity); Hermes brain/issues + Orca workspace; Windows: thử OpenHuman. Shim ~/.config/orca/linux-orca-cli-shim (PATH .zshrc); worktrees ~/orca/workspaces; glab token ở config.yml, env GITLAB_TOKEN override → 401.