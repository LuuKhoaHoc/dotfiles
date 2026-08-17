#!/usr/bin/env python3
"""Start Azure VM 9router-vm (GitHub Actions version).
Credentials come from Actions secrets via env: AZURE_CLIENT_ID / AZURE_TENANT_ID / AZURE_CLIENT_SECRET.
Exit codes: 0 running/started, 1 not yet running, 2 auth error, 3 VM not found.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

VM_NAME = "9router-vm"
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
    # data=b"" is REQUIRED to send Content-Length: 0 — without it Azure intermittently returns 405/411
    req = urllib.request.Request(url, data=b"", headers={"Authorization": f"Bearer {token}"}, method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        data = r.read()
        return json.loads(data) if data else {}


def main():
    cfg = {
        "client_id": os.environ.get("AZURE_CLIENT_ID", ""),
        "tenant_id": os.environ.get("AZURE_TENANT_ID", ""),
        "client_secret": os.environ.get("AZURE_CLIENT_SECRET", ""),
    }
    if not all(cfg.values()):
        print("Missing AZURE_CLIENT_ID/TENANT_ID/CLIENT_SECRET env")
        sys.exit(2)

    s, r = post(f"https://login.microsoftonline.com/{cfg['tenant_id']}/oauth2/v2.0/token", {
        "client_id": cfg["client_id"],
        "client_secret": cfg["client_secret"],
        "grant_type": "client_credentials",
        "scope": "https://management.core.windows.net/.default",
    })
    if "access_token" not in r:
        print("Token failed:", r.get("error_description") or r)
        sys.exit(2)
    token = r["access_token"]

    try:
        subs = get("https://management.azure.com/subscriptions?api-version=2020-01-01", token)
    except urllib.error.HTTPError as e:
        print(f"Subscriptions HTTP {e.code} — check role assignment")
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
                    st = next((x["code"] for x in iv.get("statuses", []) if x.get("code", "").startswith("PowerState/")), "?")
                    if st == "PowerState/running":
                        print("VM already running — nothing to do")
                        sys.exit(0)
                    print(f"VM state: {st} — sending start...")
                except Exception:
                    pass
                for attempt in range(3):
                    try:
                        post_action(f"https://management.azure.com{vid}/start?api-version={API}", token)
                        print("Start command sent")
                        break
                    except urllib.error.HTTPError as e:
                        if attempt == 2:
                            print(f"Start HTTP {e.code}")
                            sys.exit(3)
                        print(f"Start HTTP {e.code} — retrying ({attempt + 1}/3)...")
                        time.sleep(5)
                for i in range(6):
                    time.sleep(20)
                    try:
                        iv = get(f"https://management.azure.com{vid}/instanceView?api-version={API}", token)
                        state = next((x["code"] for x in iv.get("statuses", []) if x.get("code", "").startswith("PowerState/")), "?")
                        print(f"  [{i + 1}] {state}")
                        if state == "PowerState/running":
                            print("VM running — gateway online")
                            sys.exit(0)
                    except Exception:
                        pass
                print("Not running after 2 min")
                sys.exit(1)
    print(f"VM '{VM_NAME}' not found")
    sys.exit(3)


if __name__ == "__main__":
    main()
