# glab 401 — 4 lớp nguồn token chết (gitlab.vppos.vn, verify 19/08/2026)

## Rule gốc (glab auth precedence — docs chính thức)
gitlab.com/gitlab-org/cli/-/blob/main/docs/source/auth/login.md:
- `GITLAB_TOKEN`, `GITLAB_ACCESS_TOKEN`, `OAUTH_TOKEN` env vars **override mọi thứ** (keyring, config.yml, CI_JOB_TOKEN)
- `glab auth login` mặc định lưu token vào **OS keyring** (Secret Service trên Linux); nếu không có keyring hoặc `--insecure-storage` → plaintext `~/.config/glab-cli/config.yml`
- Trong CI (`CI`/`GITLAB_CI` set) glab lưu vào config file thay vì keyring

## Symptom
- Orca UI banner: "Some GitLab source hosts unavailable: Local Linux provider auth needed"
- Issues/MRs tab: `Failed to load Issues; Command failed: glab api ... glab: 401 Unauthorized (HTTP 401)`

## Lớp 1: Shell rc files (`~/.zshrc`, `~/.zshenv`)
```bash
grep -rn "GITLAB" ~/.zshrc ~/.zshenv ~/.bashrc ~/.profile
```
Fix: backup rồi `sed -i '/GITLAB_TOKEN=/d'` cả 2 file (user zsh — cả `.zshrc` lẫn `.zshenv`).

## Lớp 2: `~/.config/environment.d/*.conf` (systemd user session — nguồn chính, dễ bỏ sót)
```bash
grep -rn "GITLAB" ~/.config/environment.d/ /etc/environment.d/ /etc/environment
```
File này được **systemd --user đọc lúc login** → env vào MỌI app desktop (Zed, Orca, Electron...), KHÔNG phụ thuộc shell. Máy này token chết nằm trong `99-zed-tokens.conf` (file Zed MCP tokens).
Fix:
```bash
cp ~/.config/environment.d/99-zed-tokens.conf{,.bak}
sed -i '/^GITLAB_TOKEN=/d' ~/.config/environment.d/99-zed-tokens.conf
systemctl --user unset-environment GITLAB_TOKEN   # xóa khỏi session hiện tại
systemctl --user daemon-reexec                      # systemd đọc lại environment.d (BẮT BUỘC sau khi sửa file)
systemctl --user show-environment | grep -i gitlab  # verify: GONE
```
Lưu ý: `unset-environment` một mình KHÔNG ăn khi file environment.d vẫn còn dòng — phải sửa file + reexec.

## Lớp 3: Process cha giữ env cũ trong memory (Hermes serve / desktop session)
Ngay cả khi đã sạch file, **process đang chạy vẫn giữ env cũ**. Điển hình: Hermes serve process (cha của mọi terminal session) khởi động TRƯỚC khi dọn → mọi shell con (kể cả lệnh launch Orca) kế thừa token chết. Đây là lý do "restart Orca rồi vẫn 401".
Debug chain:
```bash
tr '\0' '\n' < /proc/<pid>/environ | grep GITLAB   # đọc env từng nút
ps -o ppid= -p <pid>                                 # đi ngược cha liên tục
```
Fix tức thì (không cần restart Hermes): launch app với env sạch
```bash
env -u GITLAB_TOKEN -u GITLAB_PAT -u GITLAB_ACCESS_TOKEN -u OAUTH_TOKEN /opt/stably-orca/orca-ide
```
Fix dài hạn: restart Hermes / logout-login để session sạch hẳn.

## Lớp 4: Config copies Orca tự đọc (token trong codex config.toml)
Orca quản lý nhiều bản copy của codex config, trong đó `[mcp_servers."mcp-server-gitlab"]` chứa `--token=glpat-...` — Orca đọc token này và **tự set `GITLAB_TOKEN` cho daemon** khi spawn. Daemon mới sau restart VẪN có token cũ nếu các file này chưa sửa:
- `~/.codex/config.toml`
- `~/.config/orca/codex-runtime-home/home/config.toml`
- `~/.config/orca/codex-accounts/<uuid>/home/config.toml` (2 accounts)
- `.bak` files không cần sửa (chỉ backup)

Fix: lấy token hợp lệ từ `~/.config/glab-cli/config.yml`, thay tất cả `--token=glpat-...`:
```python
import yaml, re, glob
valid = yaml.safe_load(open('/home/luukhoahoc/.config/glab-cli/config.yml'))['hosts']['gitlab.vppos.vn']['token']
for p in ['~/.codex/config.toml', '~/.config/orca/codex-runtime-home/home/config.toml'] + glob.glob('~/.config/orca/codex-accounts/*/home/config.toml'):
    c = open(p).read()
    open(p, 'w').write(re.sub(r'--token=glpat-[^"]+', f'--token={valid}', c))
```

## Debug chain chuẩn (thứ tự làm)
1. `glab auth status` → đọc cảnh báo "Token is from environment variable..."
2. `type glab` → phân biệt wrapper (alias/op plugin) vs plain path
3. `env | grep -E 'GITLAB|GLAB'` → biến nào đang set
4. Quét 4 lớp nguồn (trên)
5. **So sha1 token thay vì in giá trị** (Hermes redact token trong output, không đọc được trực tiếp): `hashlib.sha1(token).hexdigest()` cho token valid vs token trong `/proc/<pid>/environ` → match là ra nguồn; `grep -rlo 'glpat-...' ~/.config/orca/` tìm file chứa token
6. Fix từng lớp, cuối cùng kill sạch Orca rồi launch với `env -u` và verify daemon env:
```bash
pkill -f "[s]tably-orca"   # bracket trick — `pkill -f "stably-orca"` tự giết shell đang chạy lệnh!
sleep 3; pgrep -f "[o]rca" | wc -l   # 0 = sạch
env -u GITLAB_TOKEN -u GITLAB_PAT /opt/stably-orca/orca-ide &
sleep 10
# verify daemon không còn token:
python3 -c "import os; pid=os.popen('pgrep -f daemon-entry.js').read().strip(); print([e for e in open(f'/proc/{pid}/environ','rb').read().split(b'\x00') if e.startswith(b'GITLAB')] or 'CLEAN')"
```

## Kiểm tra cuối
```bash
env -u GITLAB_TOKEN glab auth status          # ✓ Logged in as luukhoahoc
env -u GITLAB_TOKEN glab api "projects/vppos-team%2Ferp-admin/merge_requests?state=opened&per_page=1" | head -c 200   # HTTP 200
```

## Rule bền
- Không export `GITLAB_TOKEN` trong shell rc; không đặt trong environment.d trừ khi token đang sống và cố ý (Zed MCP cần thì dùng token hợp lệ)
- Token GitLab hợp lệ sống ở `~/.config/glab-cli/config.yml` (keyring càng tốt — `glab auth login --hostname gitlab.vppos.vn`)
- Khi token hết hạn: `glab auth login` lại, ĐỪNG export env var
- Orca managed homes không có glab config riêng — dùng chung config user; nhưng config.toml của codex có thể mang token GitLab cho MCP và Orca tự inject vào daemon env
- `pkill -f "<pattern>"` tự match chính cmdline của pkill → luôn dùng bracket `[p]attern`
- Sau khi sửa mọi file env: `systemctl --user daemon-reexec` + restart app + nếu còn nhiễm từ process cha thì `env -u` khi launch