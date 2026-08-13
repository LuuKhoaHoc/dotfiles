# mattpocock/skills rename map (verified 2026-08-12)

Upstream renames/merges that leave stale copies in local trees. All evidence from `git log --all --diff-filter=R --name-status` on mattpocock/skills.

| Old local name | Current upstream name | Evidence |
|---|---|---|
| `review` | `code-review` | commit `14c13c5` "Rename review skill to code-review and promote to engineering" |
| `diagnose` | `diagnosing-bugs` | commit `221ffca`, `R097 skills/engineering/diagnose → skills/engineering/diagnosing-bugs` |
| `to-prd` | `to-spec` | commit `386d4ff` "Rename /to-prd → /to-spec. 'spec' is now the single through-line term" |
| `to-issues` | `to-tickets` | commit `386d4ff` "Merge /to-plan + /to-issues into one /to-tickets skill; delete /to-issues" |
| `debug` | (never upstream) | old "Diagnosis Loop" variant, byte-identical description to `diagnose` — delete |
| `writing-great-skills` | `writing-for-agents` | upstream removed it (was added in `bc4cf90`), replaced by `writing-for-agents` |

## Upstream layout

```
skills/{engineering,productivity,misc,in-progress,deprecated}/<name>/SKILL.md
```
- `in-progress/` = experimental but still shipped (claude-handoff, loop-me, setup-ts-deep-modules, writing-beats/fragments/shape)
- `deprecated/` = only a README remains
- README warning: "installing both [plugin + skills.sh] leaves you with every skill twice"

## 2026-08-12 session outcome (this user's dotfiles)

- 64 → 60 skills: removed `debug`, `diagnose`, `review`, `to-issues`, `to-prd`, `writing-great-skills`
- Updated 15 skills to upstream `main` (ask-matt, grilling, tdd, prototype, wizard, triage, wayfinder, code-review, diagnosing-bugs, to-spec, to-tickets, claude-handoff, loop-me, setup-matt-pocock-skills, improve-codebase-architecture) — verified NO local-only files existed before overwriting
- Added `wait-what`, `writing-for-agents` (the 2 upstream skills the local tree lacked)
- Fixed dangling reference: `decision-mapping` body `/to-prd` → `/to-spec` (ask-matt's new version already pointed at `/writing-for-agents`)
- `.skill-lock.json`: removed 5 entries (diagnose, review, to-issues, to-prd, writing-great-skills) so `npx skills update` won't restore them
- Hermes mirror synced by hand (cp): 13 updated + 4 added + 1 removed; verified with `cmp`
- Commit `0bcaa27` on dotfiles `main`
