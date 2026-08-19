---
name: gitlab-env-token-pollution
description: Use when glab/GitLab API returns 401 despite stored auth.
---

# GitLab token env pollution (401 hunt)

## Trigger
- `glab api ...` → 401 Unauthorized, but `env -u GITLAB_TOKEN glab auth status` shows "Logged in"
- Orca GitLab pane: "Failed to load issues: glab: 401" + "Local Linux provider auth needed"
- Any agent tool suddenly 401s on GitLab

## Root cause chain (all three can exist at once)
glab resolves credentials: **env var > keyring > config.yml**. A stale/expired `GITLAB_TOKEN` in ANY source overrides the valid stored token.

1. **Shell rcs**: `~/.zshrc`, `~/.zshenv`, `~/.bashrc` export `GITLAB_TOKEN`
2. **systemd user env**: `~/.config/environment.d/*.conf` (e.g. `99-zed-tokens.conf`) — affects ALL desktop apps (Orca Electron daemon runs under systemd user session → inherits this)
3. **Live process env**: daemons started BEFORE cleanup keep the stale token (e.g. Hermes serve is parent of every terminal session; launching Orca from terminal inherits it). `unset` in one shell does NOT propagate to new shells spawned from the polluted parent.

## Diagnosis steps
```bash
# 1. Where do files set it?
grep -rn "GITLAB" ~/.zshrc ~/.zshenv ~/.zprofile ~/.bashrc ~/.config/environment.d/ /etc/environment 2>/dev/null

# 2. systemd user session state
systemctl --user show-environment | grep -i gitlab

# 3. Live process env (the sneaky one)
grep -r "GITLAB_TOKEN" /proc/*/environ 2>/dev/null | grep -v "Permission" | head
# or per-process:
tr '\0' '\n' < /proc/<PID>/environ | grep GITLAB
# Compare token via python (sha1) — Hermes redacts tokens in tool output, so compare hashes:
python3 -c "
import hashlib,os
tok=open('/proc/<PID>/environ','rb').read().split(b'GITLAB_TOKEN=')[1].split(b'\x00')[0]
print(len(tok), hashlib.sha1(tok).hexdigest()[:12])"

# 4. Where does Orca inject the token? It reads ~/.codex/config.toml mcp-server-gitlab --token and copies to:
#    ~/.config/orca/codex-runtime-home/home/config.toml
#    ~/.config/orca/codex-accounts/*/home/config.toml
#    (daemon env finally gets GITLAB_TOKEN from one of these)
```

## Fix sequence (in order)
1. Remove `GITLAB_TOKEN` from `~/.zshrc`, `~/.zshenv`, `~/.bashrc` (backup first)
2. Remove from `~/.config/environment.d/*.conf`, then `systemctl --user daemon-reexec` so systemd re-reads environment.d (plain `unset-environment` alone may not stick; re-exec does)
3. Copy the VALID token (from `~/.config/glab-cli/config.yml` `hosts.<host>.token` — that's the one `glab auth login` stores, verify with `env -u GITLAB_TOKEN glab api ...`) into:
   - `~/.codex/config.toml` (mcp-server-gitlab `--token=` arg)
   - `~/.config/orca/codex-runtime-home/home/config.toml`
   - `~/.config/orca/codex-accounts/*/home/config.toml`
   Do it with python regex `--token=glpat-[^"]+` so Hermes redaction doesn't corrupt the write.
4. Kill Orca ENTIRELY (`pkill -f "[s]tably-orca"` + `pkill -f "[o]rca-ide"` — bracket trick avoids self-match), then relaunch with:
   `env -u GITLAB_TOKEN -u GITLAB_PAT -u GITLAB_ACCESS_TOKEN -u OAUTH_TOKEN /opt/stably-orca/orca-ide`
   Closing the window does NOT kill the daemon (headless daemon keeps old env).
5. Verify: new daemon env has NO GITLAB_TOKEN, and `env -u GITLAB_TOKEN glab api ...` returns 200.

## Pitfalls
- Hermes redacts token strings in output (`[gitlab_token_redacted]`) — NEVER trust displayed token text for comparison; use sha1 or exact-match booleans in python.
- `pkill -f "stably-orca"` also matches your own shell command → use `[s]tably-orca` bracket trick.
- Restarting Orca from a terminal whose parent (Hermes serve) still has the stale token re-poisons it. Launch with `env -u GITLAB_TOKEN`, or restart Hermes itself.
- `glab auth login` on this machine stores plaintext in config.yml (no keyring in use); `--insecure-storage` is the norm here.
- After full cleanup, a logout/login or Hermes restart permanently clears the live-process pollution.