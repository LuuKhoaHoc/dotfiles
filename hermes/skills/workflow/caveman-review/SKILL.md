---
name: caveman-review
description: >
  Ultra-compressed code review comments. Cuts noise from PR feedback while preserving
  the actionable signal. Each comment is one line: location, problem, fix. Use when user
  says "review this PR", "code review", "review the diff", "/review", or invokes
  /caveman-review. Auto-triggers when reviewing pull requests.
---

Write code review comments terse and actionable. One line per finding. Location, problem, fix. No throat-clearing.

## Rules

**Format:** `L<line>: <problem>. <fix>.` — or `<file>:L<line>: ...` when reviewing multi-file diffs.

**Output style:** When user is in caveman mode (terse CLI output), skip markdown: no `**bold**`, no `*` bullet lists, no markdown headers. Use plain text section labels. Emoji prefixes inline OK.

**Severity prefix (optional, when mixed):**
- `🔴 bug:` — broken behavior, will cause incident
- `🟡 risk:` — works but fragile (race, missing null check, swallowed error)
- `🔵 nit:` — style, naming, micro-optim. Author can ignore
- `❓ q:` — genuine question, not a suggestion

**Language:** User prefers Vietnamese for communication, code/identifiers/paths stay English.

**Drop:**
- "I noticed that...", "It seems like...", "You might want to consider..."
- "This is just a suggestion but..." — use `nit:` instead
- "Great work!", "Looks good overall but..." — say it once at the top, not per comment
- Restating what the line does — the reviewer can read the diff
- Hedging ("perhaps", "maybe", "I think") — if unsure use `q:`

**Keep:**
- Exact line numbers
- Exact symbol/function/variable names in backticks
- Concrete fix, not "consider refactoring this"
- The *why* if the fix isn't obvious from the problem statement

## Examples

❌ "I noticed that on line 42 you're not checking if the user object is null before accessing the email property. This could potentially cause a crash if the user is not found in the database. You might want to add a null check here."

✅ `L42: bug: user can be null after .find(). Add guard before .email.`

❌ "It looks like this function is doing a lot of things and might benefit from being broken up into smaller functions for readability."

✅ `L88-140: nit: 50-line fn does 4 things. Extract validate/normalize/persist.`

❌ "Have you considered what happens if the API returns a 429? I think we should probably handle that case."

✅ `L23: risk: no retry on 429. Wrap in withBackoff(3).`

## Auto-Clarity

Drop terse mode for: security findings (CVE-class bugs need full explanation + reference), architectural disagreements (need rationale, not just a one-liner), and onboarding contexts where the author is new and needs the "why". In those cases write a normal paragraph, then resume terse for the rest.

## Boundaries

Reviews only — does not write the code fix, does not approve/request-changes, does not run linters. Output the comment(s) ready to paste into the PR. "stop caveman-review" or "normal mode": revert to verbose review style.

## Posting to GitLab MR via glab

When user asks to post review directly to a GitLab MR:

```bash
# Write comment to temp file first
cat > /tmp/mr_review.md << 'EOF'
...review content...
EOF

# Post using -m with command substitution (NOT --body, NOT -F, NOT --message-file)
glab mr note create <MR_ID> -m "$(cat /tmp/mr_review.md)"

# Clean up
rm /tmp/mr_review.md
```

**Pitfalls:**
- `--body` — does not exist, errors out
- `-F` / `--message-file` — does not exist in this glab version
- `glab mr comment` — wrong subcommand, use `glab mr note create`
- Heredoc directly in `-m` arg can fail with special chars — write to file first, then `$(cat)`
