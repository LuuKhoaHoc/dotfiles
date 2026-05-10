# Claude Code Plugin Migration to Hermes

Case: `EveryInc/compound-engineering-plugin`

## Migration Path
- Source: `~/.hermes/plugins/compound-engineering-plugin/plugins/compound-engineering/skills/`
- Canonical: `~/.agents/skills/ce/`
- Hermes Mirror: `~/.hermes/skills/ce/`

## Automated Symlink Sequence
```bash
# 1. Create canonical category
mkdir -p ~/.agents/skills/ce

# 2. Link from plugin source to canonical
for skill in ~/.hermes/plugins/compound-engineering-plugin/plugins/compound-engineering/skills/*/; do
    ln -sf "$skill" ~/.agents/skills/ce/$(basename "$skill")
done

# 3. Link from canonical to Hermes
mkdir -p ~/.hermes/skills/ce
for skill in ~/.agents/skills/ce/*/; do
    ln -sf "$skill" ~/.hermes/skills/ce/$(basename "$skill")
done
```

## Why this way?
- `hermes plugins update` updates the git repo in `~/.hermes/plugins/`.
- The symlink chain ensures the latest code is always live in both `~/.agents/` and `~/.hermes/skills/` without manual copying.
