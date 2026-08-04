#!/usr/bin/env python3
"""Aggregate GitLab data for status reports (PO/CTO).

Run via `terminal` (NOT execute_code — its sandbox lacks user env vars):
    python3 /tmp/gitlab_aggregate.py

Needs GITLAB_TOKEN env var (terminal session). Overridable: GITLAB_HOST, GITLAB_PROJECT_ID, GITLAB_MILESTONE.
"""
import os
import json
import urllib.request
import urllib.parse
from collections import Counter
from datetime import datetime, timedelta

HOST = os.environ.get("GITLAB_HOST", "gitlab.vppos.vn")
PID = os.environ.get("GITLAB_PROJECT_ID", "9")
MILESTONE = os.environ.get("GITLAB_MILESTONE", "")
TOKEN = os.environ["GITLAB_TOKEN"]
BASE = f"https://{HOST}/api/v4"

MFE_LABELS = ("sale", "finance", "product", "employee", "hr", "apps-dashboard", "shell")


def api(path, params=None):
    url = f"{BASE}{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"PRIVATE-TOKEN": TOKEN})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())


def mfe_of(labels):
    return next((l for l in labels if l in MFE_LABELS), "no-mfe")


def main():
    issues = api(f"/projects/{PID}/issues", {"state": "opened", "scope": "all", "per_page": 100})
    print(f"OPEN ISSUES: {len(issues)}")
    print("  by MFE:", dict(Counter(mfe_of(i.get("labels") or []) for i in issues)))
    print("  by status label:", dict(Counter(
        next((l for l in (i.get("labels") or []) if l.startswith("status::")), "status::(none)")
        for i in issues)))
    print("  ready-for-agent:", sum(1 for i in issues if "ready-for-agent" in (i.get("labels") or [])),
          "/ ready-for-human:", sum(1 for i in issues if "ready-for-human" in (i.get("labels") or [])))
    un = [i for i in issues if not i.get("assignees")]
    print(f"  unassigned ({len(un)}):")
    for i in un:
        print(f"    #{i['iid']} {i['title'][:80]}")
    bl = [i for i in issues if "status::blocked" in (i.get("labels") or [])]
    print(f"  blocked ({len(bl)}):")
    for i in bl:
        asg = ", ".join(a["username"] for a in i.get("assignees") or []) or "unassigned"
        print(f"    #{i['iid']} [{asg}] {i['title'][:80]}")

    # Milestone progress: GET /milestones does NOT return issue counts — count via issues filter.
    if MILESTONE:
        mi = api(f"/projects/{PID}/issues", {"milestone": MILESTONE, "state": "all", "scope": "all", "per_page": 100})
        st = Counter(i["state"] for i in mi)
        print(f"\nMILESTONE '{MILESTONE}': {len(mi)} issues -> {dict(st)}")
        mfe = Counter(mfe_of(i.get("labels") or []) for i in mi)
        print("  by MFE:", dict(mfe))

    mrs = api(f"/projects/{PID}/merge_requests", {"state": "opened", "per_page": 100})
    print(f"\nOPEN MRs: {len(mrs)}")
    for m in mrs:
        draft = "/draft" if m.get("work_in_progress") else ""
        print(f"  !{m['iid']}{draft} {m['title'][:70]} — {m['author']['username']} -> {m['target_branch']} ({m['detailed_merge_status']})")

    since = (datetime.utcnow() - timedelta(days=21)).strftime("%Y-%m-%dT%H:%M:%SZ")
    # updated_after filters on updated_at; filter merged_at client-side for true merge window
    merged = [m for m in api(f"/projects/{PID}/merge_requests",
                             {"state": "merged", "per_page": 100, "updated_after": since})
              if m.get("merged_at") and m["merged_at"] >= since]
    print(f"\nMERGED last 21 days: {len(merged)}")
    for m in sorted(merged, key=lambda x: x["merged_at"], reverse=True):
        print(f"  !{m['iid']} {m['merged_at'][:10]} {m['title'][:70]} — {m['author']['username']}")


if __name__ == "__main__":
    main()
