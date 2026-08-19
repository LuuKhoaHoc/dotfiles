# Debugging GitHub Actions runs without (or with) auth — verified 2026-08-15

Scenario: a scheduled GH Actions workflow failed overnight; the machine's `gh`
was not logged in and the user is busy. You can diagnose a LOT before any auth.

## 1. Unauthenticated read path (public repos)

For a PUBLIC repo you can read runs, jobs, and — key trick — **annotations**
without any token. Job LOGS (`actions/jobs/{id}/logs`) need admin rights, but
the failure reason is usually in the annotations.

```bash
# Latest runs: id, name, status, conclusion, event, branch
curl -s "https://api.github.com/repos/<owner>/<repo>/actions/runs?per_page=10"

# Jobs of a run (get job id)
curl -s "https://api.github.com/repos/<owner>/<repo>/actions/runs/<run_id>/jobs"

# FAILURE MESSAGE without auth (this is the money endpoint):
curl -s "https://api.github.com/repos/<owner>/<repo>/check-runs/<job_id>/annotations"
# -> e.g. "Process completed with exit code 3." + per-step warnings
```

The annotations give the step-level failure line. In the 2026-08-15 case it
read `failure: "Process completed with exit code 3"` — enough to map to the
script's exit-code table and pinpoint the failing branch BEFORE log access.

## 2. With `gh` logged in

```bash
gh run list --workflow <file.yml> --limit 5
gh run view <run_id> --log-failed      # only failed steps, exact lines
gh run watch <run_id> --exit-status    # wait for completion, exit nonzero on fail
```

`--log-failed` showed `VM state: PowerState/deallocated — sending start...`
then `Start HTTP 405` — the precise root cause.

## 3. `gh auth login` in a background PTY — known failure mode

`gh auth login --web` run as a Hermes background process with `pty=true`
started but its survey prompt (`? Authenticate Git with your GitHub
credentials? (Y/n)`) **never accepted input** via process write/submit
(spammed `tput: No value for $TERM` errors; the prompt redraws and ignores
input). Kill it and fall back to one of:

- Ask the user to run `gh auth login` in their own terminal (quickest).
- `gh auth login --with-token` with a PAT (or the device-flow from the
  github-auth skill), if `--with-token` doesn't hang (headless keyring issue —
  see github-auth skill for the hosts.yml fallback).
- For read-only diagnosis, stay unauthenticated (section 1) — you may not need
  login at all.

## 4. False-positive-success trap (the actual root cause lesson)

The VM-start workflow had "passed" the day before via `workflow_dispatch` —
but the VM was already running, so the script exited early at the
"already running" branch and the **start path was never executed**. The
GET-vs-POST bug (405) only surfaced on the first run where the VM was actually
deallocated.

Rule: when reviewing a script with an early-exit happy path, verify the green
run actually EXERCISED the path that matters. "Last run succeeded" is not
evidence a branch has ever run. Check the run log for the branch markers
(e.g. `"sending start..."` present/absent), or run once against the real
deallocated state.
