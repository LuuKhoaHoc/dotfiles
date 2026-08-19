#!/usr/bin/env python3
"""Start an Azure VM via REST API with SERVICE-PRINCIPAL auth (no az CLI, no login).

Durable path for GitHub-Education-claimed Azure: device-code OAuth cannot
authenticate the GitHub-federated account ("can't sign in here with a personal
account" on /common/, AADSTS9002332 on /consumers/) — use an App Registration
(client_credentials grant): token fetched fresh every run, never expires,
cron-safe forever.

Setup (one-time, in portal):
1. Microsoft Entra ID -> App registrations -> New (e.g. cron-vm-start)
   -> note Application (client) ID + Directory (tenant) ID.
2. Certificates & secrets -> New client secret (24 mo) -> copy Value once.
3. Subscription (the one that CONTAINS the VM - portal creates VMs in the
   FIRST subscription by default!) -> Access control (IAM) -> role
   "Virtual Machine Contributor" -> assign the app. Propagation 1-5 min.

Credentials file ~/.azure-vm-start.json (chmod 600):
  {"client_id": "...", "tenant_id": "...", "client_secret": "..."}

Usage: azure-vm-start [VM_NAME]   (default: 9router-vm)
Exit codes: 0 started/running, 1 not running yet, 2 auth/cred error, 3 VM not found.

NOTE (2026-08-15): the /start action MUST be POST — urllib urlopen defaults
to GET, which Azure answers with HTTP 405 Method Not Allowed.
NOTE (2026-08-17): method="POST" ALONE IS NOT ENOUGH. urllib sends NO
Content-Length header on a bodyless POST; Azure then intermittently answers
405 or 411 (hop-dependent) — the failure is FLAKY, not deterministic
(2026-08-15 GH Actions schedule failed with 405, manual dispatches passed).
Fix verified by curl: POST without Content-Length -> 411; POST with
"Content-Length: 0" -> 202 Accepted. So post_action passes data=b"" (urllib
then emits Content-Length: 0) and the start call retries 3x for transient
HTTP errors. NEVER trust a green run while the VM is already running — the
early-exit short-circuits BEFORE the start call, so it never exercises this
path (false-positive-success trap).

Same fix applied to both the local script and the GH Actions copy
(dotfiles .github/workflows/azure_vm_start.py, commit 4c9147c).
"""
import json, os, sys, time, urllib.parse, urllib.request

CFG_FILE = os.path.expanduser("~/.azure-vm-start.json")
VM_NAME = sys.argv[1] if len(sys.argv) > 1 else "9router-vm"
API = "2023-03-01"

def post(url, data):
    req = urllib.request.Request(url, data=urllib.parse.urlencode(data).encode(),
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read())
        except Exception:
            return e.code, {}

def get(url, token):
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

def post_action(url, token):
    """POST an action endpoint (start/stop/restart...). Azure returns 202 with
    an EMPTY body — json.loads on empty raises, so tolerate it. data=b"" forces
    Content-Length: 0, without which Azure intermittently 405/411s."""
    req = urllib.request.Request(url, data=b"", headers={"Authorization": f"Bearer {token}"}, method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        data = r.read()
        return json.loads(data) if data else {}

def get_token(cfg):
    s, r = post(
        f"https://login.microsoftonline.com/{cfg['tenant_id']}/oauth2/v2.0/token",
        {
            "client_id": cfg["client_id"],
            "client_secret": cfg["client_secret"],
            "grant_type": "client_credentials",
            "scope": "https://management.core.windows.net/.default",
        },
    )
    if "access_token" not in r:
        print("Token fail:", r.get("error_description") or r)
        sys.exit(2)
    return r["access_token"]

def main():
    if not os.path.exists(CFG_FILE):
        print(f"Missing {CFG_FILE} - need {{\"client_id\", \"tenant_id\", \"client_secret\"}}")
        sys.exit(2)
    cfg = json.load(open(CFG_FILE))
    token = get_token(cfg)

    try:
        subs = get("https://management.azure.com/subscriptions?api-version=2020-01-01", token)
    except urllib.error.HTTPError as e:
        print(f"API error HTTP {e.code} - check IAM role assignment (Virtual Machine Contributor)")
        sys.exit(2)
    if not subs.get("value"):
        print("No subscriptions visible - check IAM role assignment")
        sys.exit(2)

    for sub in subs.get("value", []):
        try:
            vms = get(f"https://management.azure.com/subscriptions/{sub['subscriptionId']}/providers/Microsoft.Compute/virtualMachines?api-version={API}", token)
        except Exception:
            continue
        for vm in vms.get("value", []):
            if vm.get("name") == VM_NAME:
                vid = vm["id"]
                try:
                    iv = get(f"https://management.azure.com{vid}/instanceView?api-version={API}", token)
                    st = next((s["code"] for s in iv.get("statuses", []) if s.get("code", "").startswith("PowerState/")), "?")
                    if st == "PowerState/running":
                        print("VM already running - nothing to do")
                        sys.exit(0)
                    print(f"VM is {st} - sending start...")
                except Exception:
                    pass
                for attempt in range(3):
                    try:
                        post_action(f"https://management.azure.com{vid}/start?api-version={API}", token)
                        print(f"Start sent for {VM_NAME} (sub {sub['subscriptionId']})")
                        break
                    except urllib.error.HTTPError as e:
                        if attempt == 2:
                            print(f"Start failed HTTP {e.code}")
                            sys.exit(3)
                        print(f"Start HTTP {e.code} - retrying ({attempt + 1}/3)...")
                        time.sleep(5)
                for i in range(6):
                    time.sleep(20)
                    try:
                        iv = get(f"https://management.azure.com{vid}/instanceView?api-version={API}", token)
                        state = next((s["code"] for s in iv.get("statuses", []) if s.get("code", "").startswith("PowerState/")), "?")
                        print(f"   [{i+1}] powerState: {state}")
                        if state == "PowerState/running":
                            print("VM running - gateway online")
                            sys.exit(0)
                    except Exception:
                        pass
                print("Not running after 2 min - check portal")
                sys.exit(1)
    # Azure conceals existence: list-empty + 403 on direct GET = role scope
    # problem, NOT missing VM. Print what the SP can see for diagnosis.
    print(f"VM '{VM_NAME}' not found in visible subscriptions:")
    for sub in subs.get("value", []):
        print(f"   - {sub['subscriptionId']} | {sub.get('displayName')} | {sub.get('state')}")
    sys.exit(3)

if __name__ == "__main__":
    main()