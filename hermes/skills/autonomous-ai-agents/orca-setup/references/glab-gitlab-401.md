# glab 401 Unauthorized — env token override (gitlab.vppos.vn)

## Symptom
- Orca UI banner: "Some GitLab source hosts unavailable: Local Linux provider auth needed"
- Issues/MRs tab: `Failed to load Issues; Command failed: glab api -i projects/vppos-team%2Ferp-admin/merge_requests?page=1&per_page=50&... glab: 401 Unauthorized (HTTP 401)`

## Diagnosis path (đã verify)
1. `glab auth status` → `401` + "Token is from environment variable GITLAB_TOKEN. A wrapper may be injecting a different or expired token."
2. `type glab` → `/usr/bin/glab` (plain path, không wrapper — token do shell rc set)
3. `env | grep GITLAB_TOKEN` → set; grep rc files → dòng `GITLAB_TOKEN="glpat-..."` xuất hiện ở **cả** `~/.zshrc` lẫn `~/.zshenv` (cùng giá trị, len 51)
4. `env -u GITLAB_TOKEN glab auth status` → ✓ Logged in as `luukhoahoc` từ `~/.config/glab-cli/config.yml`
5. `env -u GITLAB_TOKEN glab api -i "projects/vppos-team%2Ferp-admin/merge_requests?state=opened"` → HTTP 200

## Root cause
glab ưu tiên **env var > config file**. Token env cũ hết hạn/revoke → mọi API call 401, kể cả qua Orca (Orca shell-out `glab api`). Config file token vẫn sống nhưng bị env override.

## Fix
```bash
cp ~/.zshrc ~/.zshrc.bak-gitlab && cp ~/.zshenv ~/.zshenv.bak-gitlab
sed -i '/GITLAB_TOKEN=/d' ~/.zshrc ~/.zshenv
env -u GITLAB_TOKEN glab auth status   # verify: ✓ Logged in as luukhoahoc
```
Sau đó **restart Orca từ UI** — process cũ (check `ps aux | grep orca-ide`, vd PID 24155) giữ env cũ trong memory, `orca quit` không tồn tại.

## Rule bền
- Token GitLab hợp lệ nằm ở `~/.config/glab-cli/config.yml` (qua `glab auth login --hostname gitlab.vppos.vn`)
- Không export `GITLAB_TOKEN` trong shell rc — nó override config và là nguồn 401 về sau; nếu token hết hạn thì `glab auth login` lại, đừng export env var
- Orca managed homes (`~/.config/orca/codex-accounts/*/home/`) không có glab config riêng — chúng dùng chung config user thật
