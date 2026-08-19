# Azure ARM + urllib: intermittent 405/411 on bodyless POST (verified 2026-08-17)

## Symptom

`azure-vm-start` fails FLAKILY on the `/start` call — not every run:

```
VM state: PowerState/deallocated — sending start...
Start HTTP 405
##[error]Process completed with exit code 3.
```

2026-08-15 GH Actions **schedule** run (02:52 UTC) failed with 405; **manual
dispatches** an hour+ later succeeded with identical code+secrets. Local runs
interleaved success/failure. 405 alone = ambiguous (could be wrong method **or**
missing Content-Length); the same hop that 405s may 411 on the next attempt.

## Root cause (two layers)

1. `urllib.request.urlopen` defaults to **GET** → Azure answers `GET {vmId}/start`
   with `405 Method Not Allowed`. Fix layer 1: `method="POST"` on the Request.
2. Even with `method="POST"`, urllib sends a bodyless POST with **NO
   `Content-Length` header** → Azure (load-balanced, hop-dependent) intermittently
   rejects with **405 or 411**. Fix layer 2: `data=b""` on the Request — urllib
   then emits `Content-Length: 0`.

`method="POST"` alone is NOT enough — that combination is exactly what failed
intermittently on 2026-08-15/17.

## Repro recipe (keep VM running — `/start` on a running VM is idempotent, 202)

```bash
VMID=/subscriptions/<sub>/resourceGroups/<RG>/providers/Microsoft.Compute/virtualMachines/<vm>
TOK=<access_token>  # client_credentials grant, scope https://management.core.windows.net/.default

# WITHOUT Content-Length → 411 (or 405 on other hops)
curl -sS -o /dev/null -D - -X POST -H "Authorization: Bearer $TOK" \
  "https://management.azure.com${VMID}/start?api-version=2023-03-01" | head -1

# WITH Content-Length: 0 → 202 Accepted
curl -sS -o /dev/null -D - -X POST -H "Content-Length: 0" -H "Authorization: Bearer $TOK" \
  "https://management.azure.com${VMID}/start?api-version=2023-03-01" | head -1
```

## Fix (applied to both copies, dotfiles commit 4c9147c)

```python
def post_action(url, token):
    # data=b"" forces Content-Length: 0 — without it Azure intermittently 405/411s
    req = urllib.request.Request(url, data=b"", headers={"Authorization": f"Bearer {token}"}, method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        data = r.read()
        return json.loads(data) if data else {}  # 202 body is EMPTY — tolerate
```

Plus a 3-attempt retry (5s sleep) around the start POST for transient HTTP errors.

## Verification protocol (learned the hard way)

- **Never trust a green run while the VM is already running.** The "already
  running — nothing to do" early-exit short-circuits BEFORE the start call, so
  the start path is never exercised (false-positive-success trap). To truly
  verify a fix you must run against a **deallocated** VM (or hit the endpoint
  directly with curl while it's running — `/start` is idempotent).
- Repro locally with curl (above) before re-running the GH workflow — faster
  than a runner round-trip, no secrets in logs.
- GH Actions schedule runs can lag the cron slot by 30-90 min (and are sometimes
  dropped entirely, e.g. 2026-08-17 02:00 UTC never appeared) — absence of a run
  ≠ failure; use `workflow_dispatch` for deterministic manual checks.
- Same bug existed in BOTH the local script (`~/.local/bin/azure-vm-start`) and
  the GH Actions copy (`dotfiles/.github/workflows/azure_vm_start.py`) — patch
  both, diff them after.