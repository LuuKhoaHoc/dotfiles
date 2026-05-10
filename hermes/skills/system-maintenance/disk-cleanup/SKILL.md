---
name: disk-cleanup
description: Analyze and reclaim disk space on Arch Linux without breaking running services
triggers:
  - "disk full"
  - "disk usage"
  - "out of space"
  - "disk 100%"
  - "clean cache"
category: system-maintenance
---

# Disk Cleanup — Arch Linux

Goal: reclaim disk space without disrupting running services.

## Phase 1: Analysis

```bash
# Top-level consumption
sudo du -h --max-depth=1 / 2>/dev/null | sort -hr | head -20

# Docker-specific
docker system df

# Pacman cache size
du -sh /var/cache/pacman/pkg/
```

Typical big consumers on dev machines:
- `/var/lib/docker` — build cache + dangling images
- `/var/cache/pacman` — old package versions
- `~/.cache/` — build/tool caches (paru, uv, camoufox, pnpm)
- `~/.local/share/` — large application data

## Phase 2: Safe Reclamation

These targets are all cache/build artifacts — safe to delete, no service impact.

### Docker (largest bang for buck)
```bash
# Build cache — typically 10-15G on dev machines
docker builder prune -a -f

# Dangling/unused images (keeps tagged images)
docker image prune -a -f
```

### Pacman (Arch)
```bash
# Remove all but last 1 installed version of each package
sudo paccache -r -k 1

# AUR helpers — paru/yay
paru -c --noconfirm        # needs sudo
yay -c --noconfirm
```

### Tool caches
```bash
# UV (Python)
uv cache clean

# PNPM
pnpm store prune

# Rust
cargo clean --release

# npm/yarn (global)
npm cache clean --force
```

### Browser / app caches
```bash
rm -rf ~/.cache/camoufox
rm -rf ~/.cache/opencode
rm -rf ~/.cache/wallust
rm -rf ~/.cache/oh-my-opencode
```

## Phase 3: Verify
```bash
df -h /
```

## Verified Reclamation Sizes (2026-05-07)
| Target | Command | Reclaimed |
|--------|---------|-----------|
| Docker build cache | `docker builder prune -a -f` | **12.5G** |
| Docker dangling images | `docker image prune -a -f` | **2.5G** |
| Pacman old pkgs | `sudo paccache -r -k 1` | **385M** |
| UV cache | `uv cache clean` | **1.2G** |
| Paru AUR cache | `sudo paru -c --noconfirm` | ~2.7G |
| Camoufox | `rm -rf ~/.cache/camoufox` | ~1.4G |
| Yay AUR cache | `yay -c --noconfirm` | ~800M |

Total on this machine: **76% → 59%** (~19G freed)

## Gotchas
- **paru/yay cache clean** requires sudo on Arch
- Docker `builder prune -a` can take a while on first run (deleting many layers)
- Some caches in `~/.cache/` may need elevated permissions — use `sudo rm -rf` for those
- Always check `docker system df` before and after to confirm impact
- Volumes (`docker volume ls`) occasionally grow large — check with `docker system df -v`

## When to Stop

Do NOT delete:
- Running container data
- `/var/lib/docker` entirely (nukes all images/containers)
- Kernel modules in `/lib/modules/`
- `/home/*/Documents`, `/home/*/Dev-Work` or project directories

Only target: caches, build artifacts, old package versions.

## Session Reference

- `references/khoahoc-disk-baseline.md` — verified cleanup on khoahoc machine (12G Docker build cache, 2.5G images, pacman/uv/paru caches). Real sizes from 2026-05-07 session.
