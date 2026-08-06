BE/PO feature request: tạo issue MỚI thay vì gộp vào issue cũ, trừ khi cùng scope + cùng assignee + follow-up nhỏ. Cùng feature + assignee + file chồng nhau → 1 issue umbrella (user: "tại sao tạo 5 issue"); chỉ tách ready-for-human/BE-decision. Khi gộp issue vừa tạo: DELETE hẳn thay vì close (close = ngụ ý đã release).
§
cuongt(id=10, Trần Cường)=Finance + HR employee-scoped specs; QuyCN(id=31, Cao Quý)=Product + HR attendance-sheet-scoped specs.
§
ERP: main clone erp-admin dùng chung (verify git status -sb); worktree per-issue ~/Projects/Hilo-Vppos/erp-admin-<iid>; branch-read: git show origin/<branch>:<path>. Documents/ERP không phải git repo.
§
BE/API mới: gọi curl trước, ghi status/trace vào issue, không lưu token.
§
ERP API: ApiResponse<T> — T=item|item[] (array ở .data), pagination ở meta.pagination; cấm wrapper/normalize (docs/solutions 2026-08-05).
§
search_files(target='files') dùng GLOB pattern, không phải regex — pattern chứa '|' trả 0 match, dễ kết luận sai "file thiếu"; xác minh từng tên bằng glob riêng hoặc dùng target='content'.
§
Hermes desktop sidebar "worktree/branch" lanes = session groups từ sessions.git_branch trong ~/.hermes/state.db, KHÔNG phải git worktree. Branch xoá remote nhưng session cũ còn → lane dư; cleanup = xoá session dính branch đã xoá (skill: hermes-desktop-state-cleanup).
§
erp-admin issue-lifecycle CI: merge job DRY_RUN=false từ 2026-08-05 (prod release/* vẫn true). Script gitlab-update-milestone-issues.py: #NNN chỉ count khi keyword liền kề ≤25 chars (ADJACENT_REF_RE) — MR mô tả false-positive cũ (vd !543) tự gây done nhầm; MR/commit fix lifecycle KHÔNG viết số issue kèm # gần keyword issue/ticket/closes/fixes/resolves/implements. Issue không tự done → trace job + resource_label_events. MR desc CẤM 'Closes #N' (auto-close → job skip 'already closed' → phải set tay); close = đã release — issue giữ OPEN + status::done, chỉ close khi deploy prod; ghi 'Issue / Ticket: #N'.
§
omp=oh-my-pi 17.x: bin ~/.bun/bin/omp, config ~/.omp/agent (AGENTS.md persona chung + RULES.md + memory mnemopi); erp-admin/.claude/CLAUDE.md + .opencode/conventions.md = issue conventions project-scope (gitignored); 'pi' mise shim=0.83 cũ hỏng — dùng omp.