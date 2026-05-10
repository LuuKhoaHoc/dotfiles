# Arch Disk Baseline — khoahoc machine

Machine: Arch Linux, NVMe, 121G root partition

## Disk Usage Breakdown (2026-05-07)

```
Root: 121G | Used: 87G | Free: 28G | 76%
After cleanup: 68G used, 48G free, 59%
```

### Top consumers

| Path | Size | Notes |
|------|------|-------|
| `/var/lib/docker` | 19G | buildkit cache + images |
| `/home/khoahoc/.local` | 12G | pnpm 4.8G, mise 3.4G, zed 1.8G |
| `/home/khoahoc/.cache` | 8.9G | paru 2.7G, uv 1.2G, camoufox 1.4G |
| `/home/khoahoc/.npm` | 3.9G | npm workspace cache |
| `/var/cache/pacman` | 3.4G | 1944 .pkg.tar.zst files |
| `/opt` | 4.2G | hermes-agent 1.5G, windsurf 933M |
| `/home/khoahoc/.rustup` | 1.3G | Rust toolchains |
| `/home/khoahoc/.bun` | 1.1G | Bun runtime |
| `/home/khoahoc/.gemini` | 804M | Gemini CLI cache |
| `/home/khoahoc/Dev-Work` | 2.0G | Project files (DO NOT DELETE) |

### Docker details

```
TYPE            TOTAL  ACTIVE  SIZE      RECLAIMABLE
Images          48     0       2.537GB   1.353GB (53%)
Build Cache     252    0       12.52GB   12.44GB (99%)
```

Active containers: 0 (safe to prune all build cache)

### Cleanup order (highest ROI first)

1. `docker builder prune -a -f` — 12.5G
2. `docker image prune -a -f` — 2.5G
3. `sudo paccache -r -k 1` — 385M (sudo required)
4. `uv cache clean` — 1.2G
5. `sudo paru -c --noconfirm` — 2.7G (sudo required)

### Manual inspection commands

```bash
# Docker reclaimable space
docker system df

# What consumed what
sudo du -h --max-depth=1 /var /home /opt 2>/dev/null | sort -hr | head -20

# Specific cache sizes
du -sh ~/.cache/paru/ ~/.cache/uv/ ~/.cache/camoufox/ ~/.local/share/pnpm/

# Pacman cache count
ls /var/cache/pacman/pkg/ | wc -l
```
