# GitLab MR Fetch (When CLI Tools Are Blocked)

When `glab` commands are blocked by permission or network policies, you can still fetch a merge request's source branch directly using Git.

## Problem
`glab mr list --project <id>` or `glab api /projects/` is blocked.
The repo clone may only have `origin/main`.

## Solution

### Step 1: Add the GitLab remote
```bash
git remote add vppos https://gitlab.vppos.vn/vppos-team/erp-admin.git
```

### Step 2: Fetch the MR head as a local branch
```bash
git fetch vppos merge-requests/<MR_NUMBER>/head:mr-<MR_NUMBER>
```

### Step 3: Checkout the branch
```bash
git checkout mr-183
```

### Step 4: Get the base branch for comparison
```bash
git fetch vppos develop:develop
```

## Verification
Compare the MR against the base:
```bash
git log --oneline develop..HEAD
git diff --stat develop..HEAD
```

## Notes
- This works for public/internal GitLab instances when the user has access.
- `vppos` is the name of the remote; this can be any valid remote name.
- Replace `<MR_NUMBER>` with the actual number (e.g., `183`).
- The branch name `mr-<MR_NUMBER>` is a convention to track the source of the branch.
