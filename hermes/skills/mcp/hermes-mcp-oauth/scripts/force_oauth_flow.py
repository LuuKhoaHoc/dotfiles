#!/usr/bin/env python3
"""Force-complete OAuth for MCP servers that never 401-challenge.

Why: some OAuth MCP servers (Google Workspace's official servers are the
known case) serve initialize + tools/list WITHOUT an auth challenge, so the
MCP SDK never triggers its OAuth flow and `hermes mcp login` reports
"no OAuth token was obtained" even with correct client_id/client_secret.

This script runs the PKCE authorization-code flow manually and writes the
token in the exact format HermesTokenStorage expects.

Usage:
  1. Run `hermes mcp login <server>` ONCE first (it "fails" but writes
     <hermes_home>/mcp-tokens/<server>.client.json, which this script reads).
  2. python force_oauth_flow.py gmail drive docs ...   # or no args = all
  3. Click Allow in the browser for each server (unverified-app warning ->
     Advanced -> Continue). A local callback server on 127.0.0.1:PORT
     captures the code; the tab can close itself.

Edit SERVERS / PORT / HERMES_HOME for your setup. Python 3.10+ with httpx
(`pip install httpx`; on Hermes Windows use
AppData/Local/hermes/hermes-agent/venv/Scripts/python.exe).
"""
import base64
import hashlib
import json
import os
import secrets
import sys
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlencode, urlparse

import httpx

HERMES_HOME = os.environ.get("HERMES_HOME") or os.path.join(
    os.path.expanduser("~"), "AppData", "Local", "hermes"
)
TOKENS_DIR = os.path.join(HERMES_HOME, "mcp-tokens")
PORT = 8765
REDIRECT = f"http://127.0.0.1:{PORT}/callback"
AUTH_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"

# server-name: (mcp url, space-separated scopes)
SERVERS = {
    "gmail": ("https://gmailmcp.googleapis.com/mcp/v1",
              "https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.compose"),
    "drive": ("https://drivemcp.googleapis.com/mcp/v1",
              "https://www.googleapis.com/auth/drive.readonly https://www.googleapis.com/auth/drive.file"),
    "docs": ("https://docsmcp.googleapis.com/mcp/v1",
             "https://www.googleapis.com/auth/drive.readonly https://www.googleapis.com/auth/drive.file "
             "https://www.googleapis.com/auth/documents.readonly https://www.googleapis.com/auth/documents"),
    "sheets": ("https://sheetsmcp.googleapis.com/mcp/v1",
               "https://www.googleapis.com/auth/drive.readonly https://www.googleapis.com/auth/drive.file "
               "https://www.googleapis.com/auth/spreadsheets.readonly https://www.googleapis.com/auth/spreadsheets"),
    "slides": ("https://slidesmcp.googleapis.com/mcp/v1",
               "https://www.googleapis.com/auth/drive.readonly https://www.googleapis.com/auth/drive.file "
               "https://www.googleapis.com/auth/presentations.readonly https://www.googleapis.com/auth/presentations"),
    "calendar": ("https://calendarmcp.googleapis.com/mcp/v1",
                 "https://www.googleapis.com/auth/calendar.calendarlist.readonly "
                 "https://www.googleapis.com/auth/calendar.events.freebusy "
                 "https://www.googleapis.com/auth/calendar.events.readonly"),
    "chat": ("https://chatmcp.googleapis.com/mcp/v1",
             "https://www.googleapis.com/auth/chat.spaces.readonly "
             "https://www.googleapis.com/auth/chat.memberships.readonly "
             "https://www.googleapis.com/auth/chat.messages.readonly "
             "https://www.googleapis.com/auth/chat.messages.create "
             "https://www.googleapis.com/auth/chat.users.readstate.readonly"),
    "people": ("https://people.googleapis.com/mcp/v1",
               "https://www.googleapis.com/auth/userinfo.profile "
               "https://www.googleapis.com/auth/contacts.readonly"),
}


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def load_client_info(server: str):
    path = os.path.join(TOKENS_DIR, f"{server}.client.json")
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception as exc:
        print(f"  !! cannot read {path}: {exc}")
        return None


class CallbackHandler(BaseHTTPRequestHandler):
    code = None

    def do_GET(self):  # noqa: N802
        qs = parse_qs(urlparse(self.path).query)
        if "code" in qs:
            CallbackHandler.code = qs["code"][0]
            body = "<html><body><h3>Authorization complete - you can close this tab.</h3></body></html>".encode()
            self.send_response(200)
        else:
            body = ("<html><body><h3>No code received. Error: " + self.path + "</h3></body></html>").encode()
            self.send_response(400)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):  # silence
        pass


def run_flow(server: str, client_id: str, client_secret: str, scopes: str) -> bool:
    verifier = b64url(secrets.token_bytes(48))
    challenge = b64url(hashlib.sha256(verifier.encode()).digest())

    params = {
        "client_id": client_id,
        "redirect_uri": REDIRECT,
        "response_type": "code",
        "scope": scopes,
        "code_challenge": challenge,
        "code_challenge_method": "S256",
        "access_type": "offline",   # required for refresh_token
        "prompt": "consent",
    }
    auth_url = AUTH_ENDPOINT + "?" + urlencode(params)

    CallbackHandler.code = None
    httpd = HTTPServer(("127.0.0.1", PORT), CallbackHandler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()

    print(f"  Opening browser for '{server}' ...")
    webbrowser.open(auth_url)

    deadline = time.time() + 300
    while CallbackHandler.code is None and time.time() < deadline:
        time.sleep(0.5)
    httpd.shutdown()

    if CallbackHandler.code is None:
        print(f"  !! TIMEOUT waiting for callback on {REDIRECT}")
        return False

    data = {
        "code": CallbackHandler.code,
        "client_id": client_id,
        "client_secret": client_secret,
        "redirect_uri": REDIRECT,
        "grant_type": "authorization_code",
        "code_verifier": verifier,
    }
    resp = httpx.post(TOKEN_ENDPOINT, data=data, timeout=30)
    if resp.status_code != 200:
        print(f"  !! token exchange failed: HTTP {resp.status_code}: {resp.text[:300]}")
        return False
    tok = resp.json()

    expires_in = int(tok.get("expires_in", 3599))
    payload = {
        "access_token": tok["access_token"],
        "token_type": tok.get("token_type", "Bearer"),
        "expires_in": expires_in,
        "scope": tok.get("scope", ""),
        "expires_at": time.time() + expires_in,  # REQUIRED by HermesTokenStorage
    }
    if tok.get("refresh_token"):
        payload["refresh_token"] = tok["refresh_token"]

    out = os.path.join(TOKENS_DIR, f"{server}.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
    print(f"  OK token saved -> {out} (refresh_token: {'yes' if 'refresh_token' in payload else 'NO'})")
    return True


def main() -> int:
    only = sys.argv[1:] if len(sys.argv) > 1 else list(SERVERS)
    os.makedirs(TOKENS_DIR, exist_ok=True)
    ok = 0
    for server in only:
        url, scopes = SERVERS[server]
        ci = load_client_info(server)
        if not ci or not ci.get("client_id"):
            print(f"===== {server}: MISSING client info - run 'hermes mcp login {server}' once first")
            continue
        print(f"===== {server} ({url})")
        if run_flow(server, ci["client_id"], ci.get("client_secret", ""), scopes):
            ok += 1
        else:
            print(f"===== {server}: FAILED")
    print(f"\nDONE: {ok}/{len(only)} servers authenticated")
    return 0 if ok == len(only) else 1


if __name__ == "__main__":
    sys.exit(main())
