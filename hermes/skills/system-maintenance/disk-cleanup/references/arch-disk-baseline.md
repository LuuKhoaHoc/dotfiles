# Arch Linux Disk Baseline — khoahoc machine

## Machine Profile
- OS: Arch Linux (Hyprland)
- Disk: NVMe 121G partition
- Primary user: khoahoc

## Disk Usage (May 2026 — before cleanup)
```
/dev/nvme0n1p5  121G   87G   28G  76%
```

## Breakdown by path
| Path | Size | Notes |
|------|------|-------|
| `/var/lib/docker` | 19G | build cache (12.5G) + images |
| `/home/khoahoc/.local` | 12G | pnpm (4.8G), mise (3.4G), zed (1.8G) |
| `/home/khoahoc/.cache` | 8.9G | paru (2.7G), uv (1.2G), camoufox (1.4G) |
| `/var/cache/pacman` | 3.4G | 1944 package files |
| `/home/khoahoc/.npm` | 3.9G | npm global packages |
| `/opt` | 4.2G | IDEs, browsers, dev tools |

## Cleanup Performed
| Command | Freed |
|---------|-------|
| `docker builder prune -a -f` | 12.52G |
| `docker image prune -a -f` | 2.537G |
| `sudo paccache -r -k 1` | 385M |
| `uv cache clean` | 1.2G |
| **Total** | **~19G** |

## Result
```
Before: 87G / 121G  →  76%
After:  68G / 121G  →  59%
```

## Remaining Uncleaned (user decision pending)
- `~/.cache/camoufox` — 1.4G
- `~/.cache/paru` — 2.7G (needs sudo)
- `~/.cache/opencode`, `wallust`, `oh-my-opencode` — ~200M

## Docker Images Kept (actively used)
- `erp-employee-local`, `erp-hr-local`, `erp-shell-local`
- `gitlab.hilo.com.vn` erp-admin images (4 variants)
- `golang:1.25-alpine`, `node:22-alpine`
- `migrate/migrate:v4.19.0`, `minio/minio`, `minio/mc`
