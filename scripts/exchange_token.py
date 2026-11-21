#!/usr/bin/env python3
import json
import os
import sys
import urllib.parse
import urllib.request

CLIENT_ID = os.environ.get("GOOGLE_OAUTH_CLIENT_ID", "")
CLIENT_SECRET = os.environ.get("GOOGLE_OAUTH_CLIENT_SECRET", "")
REDIRECT_URI = "https://developers.google.com/oauthplayground"
SECRETS_PATH = "oauth_secrets.json"

def exchange_code(auth_code):
    if not CLIENT_ID or not CLIENT_SECRET:
        print("[-] Set GOOGLE_OAUTH_CLIENT_ID and GOOGLE_OAUTH_CLIENT_SECRET first.")
        return False
    print(f"[*] Exchanging authorization code for tokens with Google...")
    url = "https://oauth2.googleapis.com/token"
    payload = urllib.parse.urlencode({
        "code": auth_code.strip(),
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "redirect_uri": REDIRECT_URI,
        "grant_type": "authorization_code",
    }).encode("utf-8")

    req = urllib.request.Request(url, data=payload, headers={
        "Content-Type": "application/x-www-form-urlencoded"
    })

    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            access_token = data.get("access_token")
            refresh_token = data.get("refresh_token")
            expires_in = data.get("expires_in")

            print("\n[+] SUCCESS! Received tokens from Google:")
            print(f"    Access Token:  {access_token[:20]}... (expires in {expires_in}s)")
            if refresh_token:
                print(f"    Refresh Token: {refresh_token[:15]}...")
            else:
                print("    Refresh Token: (kept previous refresh token)")

            update_settings_file(access_token, refresh_token)
            return True
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode("utf-8")
        print(f"[-] Google rejected token exchange ({e.code}): {err_msg}")
        return False

def update_settings_file(access_token, refresh_token):
    existing = {}
    if os.path.exists(SECRETS_PATH):
        with open(SECRETS_PATH, "r", encoding="utf-8") as f:
            existing = json.load(f)

    existing["GOOGLE_OAUTH_CLIENT_ID"] = CLIENT_ID
    existing["GOOGLE_OAUTH_CLIENT_SECRET"] = CLIENT_SECRET
    if refresh_token:
        existing["GOOGLE_REFRESH_TOKEN"] = refresh_token

    with open(SECRETS_PATH, "w", encoding="utf-8") as f:
        json.dump(existing, f, indent=2)
        f.write("\n")

    try:
        os.chmod(SECRETS_PATH, 0o600)
    except OSError:
        pass

    print(f"[+] Saved credentials to ignored file {SECRETS_PATH}.")
    print(f"[*] Build with: flutter build apk --release --dart-define-from-file={SECRETS_PATH}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        code = sys.argv[1]
    else:
        print("Usage: python3 scripts/exchange_token.py <authorization_code>")
        sys.exit(1)

    exchange_code(code)

