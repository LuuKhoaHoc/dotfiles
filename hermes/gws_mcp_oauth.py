#!/usr/bin/env python3
"""Force-complete Google Workspace MCP OAuth for Hermes.

Google's MCP servers serve initialize/tools-list WITHOUT an auth challenge,
so the MCP SDK never triggers its OAuth flow. This script runs the PKCE
authorization-code flow manually and writes tokens in the exact format
HermesTokenStorage expects (HERMES_HOME/mcp-tokens/<server>.json).
"""
import asyncio
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

HERMES_HOME = os.environ.get(
    "HERMES_HOME",
    os.path.join(os.path.expanduser("~"), "AppData", "Local", "hermes"),
)
TOKENS_DIR = os.path.join(HERMES_HOME, "mcp-tokens")
PORT = 8765
REDIRECT = f"http://127.0.0.1:{PORT}/callback"
AUTH_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"

SERVERS = {
    "gmail": ("https://gmailmcp.googleapis.com/mcp/v1",
              "https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.compose"),
    "gmail-2": ("https://gmailmcp.googleapis.com/mcp/v1",
                "https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.compose"),
    "gmail-3": ("https://gmailmcp.googleapis.com/mcp/v1",
                "https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.compose"),
    "gmail-4": ("https://gmailmcp.googleapis.com/mcp/v1",
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
    """Client info từ mcp-tokens/<server>.client.json, fallback: config oauth block, rồi env."""
    path = os.path.join(TOKENS_DIR, f"{server}.client.json")
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        pass
    # Fallback: đọc client_id/client_secret từ config.yaml mcp_servers.<server>.oauth
    # (giá trị có thể là ${VAR} — resolve từ .env / os.environ)
    try:
        import re as _re
        cfg_text = open(os.path.join(HERMES_HOME, "config.yaml"), encoding="utf-8").read()
        m = _re.search(rf"(?ms)^  {server}:\n(?:    .*\n)*?    oauth:\n((?:      .*\n)*)", cfg_text)
        oauth_raw = m.group(1) if m else ""
        oauth = {}
        for line in oauth_raw.splitlines():
            line = line.strip()
            if ":" in line:
                k, v = line.split(":", 1)
                oauth[k.strip()] = v.strip().strip('"\'')
        if oauth.get("client_id"):
            return oauth
    except Exception:
        pass
    # Fallback cuối: env GWS_MCP_CLIENT_ID / GWS_MCP_CLIENT_SECRET
    if os.environ.get("GWS_MCP_CLIENT_ID"):
        return {"client_id": os.environ["GWS_MCP_CLIENT_ID"],
                "client_secret": os.environ.get("GWS_MCP_CLIENT_SECRET", "")}
    return None


def _load_dotenv_for_secrets():
    """Nạp HERMES_HOME/.env (KEY=VALUE đơn giản) vào os.environ nếu chưa có."""
    env_path = os.path.join(HERMES_HOME, ".env")
    try:
        with open(env_path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    k = k.strip()
                    if k and k not in os.environ:
                        os.environ[k] = v.strip()
    except Exception:
        pass


class CallbackHandler(BaseHTTPRequestHandler):
    code = None

    def do_GET(self):  # noqa: N802
        qs = parse_qs(urlparse(self.path).query)
        if "code" in qs:
            CallbackHandler.code = qs["code"][0]
            body = "<html><body><h3>Authorization complete — you can close this tab.</h3></body></html>".encode()
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
        "access_type": "offline",
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
        "expires_at": time.time() + expires_in,
    }
    if tok.get("refresh_token"):
        payload["refresh_token"] = tok["refresh_token"]

    out = os.path.join(TOKENS_DIR, f"{server}.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
    print(f"  OK token saved -> {out} (refresh_token: {'yes' if 'refresh_token' in payload else 'NO'})")
    return True


def _resolve(value):
    """Resolve ${VAR} placeholders từ os.environ (đã nạp .env)."""
    import re as _re
    return _re.sub(r"\$\{([^}]+)\}", lambda m: os.environ.get(m.group(1), m.group(0)), value or "")


def main() -> int:
    only = sys.argv[1:] if len(sys.argv) > 1 else list(SERVERS)
    os.makedirs(TOKENS_DIR, exist_ok=True)
    _load_dotenv_for_secrets()
    ok = 0
    for server in only:
        url, scopes = SERVERS[server]
        ci = load_client_info(server)
        if not ci or not ci.get("client_id"):
            print(f"===== {server}: MISSING client info — chạy 'hermes mcp login {server}' 1 lần, hoặc set GWS_MCP_CLIENT_ID/GWS_MCP_CLIENT_SECRET trong .env")
            continue
        client_id = _resolve(ci["client_id"])
        client_secret = _resolve(ci.get("client_secret", ""))
        print(f"===== {server} ({url})")
        if run_flow(server, client_id, client_secret, scopes):
            ok += 1
        else:
            print(f"===== {server}: FAILED")
    print(f"\nDONE: {ok}/{len(only)} servers authenticated")
    return 0 if ok == len(only) else 1


if __name__ == "__main__":
    sys.exit(main())
