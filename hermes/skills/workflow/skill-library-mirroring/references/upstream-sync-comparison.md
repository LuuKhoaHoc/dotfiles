# Upstream Skill Sync Comparison

When checking if local skill copies are outdated vs an upstream repo (e.g. mattpocock/skills).

## Workflow

1. `git clone --depth 1 <upstream-url> /tmp/<repo-name>` — shallow clone, fast.
2. List local skill dirs: `find ~/.dotfiles/agents/skills/ -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort`
3. List upstream skill dirs (adjust depth for subfolder structure): `find /tmp/<repo>/skills/ -maxdepth 2 -mindepth 2 -type d -exec basename {} \; | sort`
4. `comm` or manual diff the two sorted lists to categorize:
   - **Renamed**: exists in both lists under different names (manual inspection needed)
   - **Deprecated**: in local, not in upstream
   - **New**: in upstream, not in local
   - **Unchanged**: in both, same name
5. Check upstream commit date vs local last sync: `git log --oneline --format="%h %ai %s" -1` in local repo.

## mattpocock/skills restructure (July 2025, confirmed July 2026)

Upstream restructured from flat `skills/<name>/` to categorized subfolders:
- `skills/engineering/` — core dev skills (tdd, triage, code-review, to-spec, to-tickets, etc.)
- `skills/misc/` — git-guardrails, scaffold-exercises, setup-pre-commit, migrate-to-shoehorn
- `skills/personal/` — edit-article, obsidian-vault
- `skills/productivity/` — grilling, grill-me, handoff, teach, writing-great-skills
- `skills/in-progress/` — experimental (claude-handoff, loop-me, wizard, to-questionnaire, writing-beats/fragments/shape)
- `skills/deprecated/` — design-an-interface, qa, request-refactor-plan, ubiquitous-language

### Key renames
- `to-issues` → `to-tickets`
- `to-prd` → `to-spec`
- `review` + `review-pr` → `code-review`
- `handoff` → `claude-handoff` (moved to in-progress/)

### Skills user explicitly keeps (local-only, not in upstream)
These are NOT overwritten during sync:
`auto-push`, `caveman`, `caveman-commit`, `compound`, `compound-refresh`,
`frontend-design`, `issue-ship`, `obsidian`, `omarchy`, `plan-first`,
`pr-to-branch`, `review-pr`

### Sync workflow (flatten subfolders to flat)

```bash
# 1. Backup
cp -r ~/.dotfiles/agents/skills ~/.dotfiles/agents/skills.bak.$(date +%Y%m%d)

# 2. Clone upstream
git clone --depth 1 https://github.com/mattpocock/skills.git /tmp/mattpocock-skills

# 3. Delete local skills NOT in keep list
# (use Python script for reliability — see execute_code pattern)

# 4. Copy upstream skills FLATTENING subfolders
# Walk skills/{engineering,misc,personal,productivity,in-progress,deprecated}/
# Copy each skill dir to ~/.dotfiles/agents/skills/<skill-name>/
# Skip skills in keep list

# 5. Verify: count final dirs, spot-check renamed skills (to-spec, to-tickets, code-review)

# 6. Clean up
rm -rf /tmp/mattpocock-skills

# 7. Commit
cd ~/.dotfiles && git add agents/skills && git commit -m "Sync mattpocock skills"
```

### Pitfalls
- **Subfolder structure**: Upstream uses `skills/<category>/<skill>/`. Local is flat `skills/<skill>/`. Must flatten on copy.
- **Keep list**: User has local-only skills that must NOT be overwritten. Always ask user which to keep before sync.
- **Renamed skills**: Old names (to-prd, to-issues, review) will be deleted. New names (to-spec, to-tickets, code-review) will be added. Verify content matches expectations.
- **in-progress skills**: Some upstream in-progress skills (writing-beats, writing-fragments, writing-shape) are work-in-progress. Include them but note status.
