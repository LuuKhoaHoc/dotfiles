#!/usr/bin/env python3
"""Extract final summaries from Hermes subagent delegation logs.

Usage:
    python read-delegation-summary.py <delegation_id|logfile>
    python read-delegation-summary.py --all   # Show all delegations in cache

Reads the final `summary=` text from each task log under the delegation cache.
Handles both:
  - `final | summary= <text>\ntimestamp final | end status=`  (leaf)
  - `final | status=completed duration=Xs summary: <text>`     (orchestrator child)
"""

import json, os, re, sys

CACHE = os.path.expanduser("~/.hermes/cache/delegation/live")

def extract_summary(logpath: str) -> str:
    with open(logpath) as f:
        content = f.read()

    # Find last "final    |" block
    markers = [
        r"final\s+\|\s+summary=",
        r"final\s+\|\s+status=completed duration=\d+\.?\d*s summary:\s*",
    ]
    best = ""
    for pat in markers:
        for m in re.finditer(pat, content):
            rest = content[m.end():]
            end = rest.find("\nfinal    | end")
            if end == -1:
                end = len(rest)
            candidate = rest[:end].strip()
            if len(candidate) > len(best):
                best = candidate
    return best or "[No final summary found]"


def show_delegation(did: str):
    manifest = os.path.join(CACHE, did, "manifest.json")
    if not os.path.exists(manifest):
        print(f"  ✗ No manifest for {did}")
        return
    with open(manifest) as f:
        meta = json.load(f)

    print(f"\n{'='*60}")
    print(f"📋 {did}  ({meta.get('completed', '?')})")
    print(f"{'='*60}")
    for t in meta.get("tasks", []):
        idx = t["index"]
        log = os.path.join(CACHE, did, f"task-{idx}.log")
        if os.path.exists(log):
            summary = extract_summary(log)
            print(f"\n── Task {idx}: {t['goal'][:100]} ──")
            # Print first ~600 chars, then note length
            if len(summary) < 600:
                print(summary)
            else:
                print(summary[:600])
                print(f"\n... ({len(summary)} total chars, see full log: {log})")


if __name__ == "__main__":
    if "--all" in sys.argv:
        for d in sorted(os.listdir(CACHE)):
            if os.path.isdir(os.path.join(CACHE, d)):
                show_delegation(d)
    elif len(sys.argv) > 1:
        target = sys.argv[1]
        if os.path.isfile(target):
            summary = extract_summary(target)
            print(summary)
        else:
            show_delegation(target)
    else:
        print("Usage: python read-delegation-summary.py <delegation_id|--all>")
