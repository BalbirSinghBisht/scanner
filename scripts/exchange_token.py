#!/usr/bin/env python3
import json
import re
import sys
import urllib.parse
import urllib.request

CLIENT_ID = "531769640142-tjrucpod4c11c6jam7apnmq0nlbsr9an.apps.googleusercontent.com"
CLIENT_SECRET = "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"
REDIRECT_URI = "https://developers.google.com/oauthplayground"
SETTINGS_REPO_PATH = "lib/services/settings_repository.dart"

def exchange_code(auth_code):
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
    print(f"[*] Updating {SETTINGS_REPO_PATH}...")
    with open(SETTINGS_REPO_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    if access_token:
        content = re.sub(
            r"static const String defaultAccessToken =\s*'[^']*';",
            f"static const String defaultAccessToken =\n      '{access_token}';",
            content
        )

    if refresh_token:
        content = re.sub(
            r"static const String defaultRefreshToken =\s*'[^']*';",
            f"static const String defaultRefreshToken =\n      '{refresh_token}';",
            content
        )

    with open(SETTINGS_REPO_PATH, "w", encoding="utf-8") as f:
        f.write(content)

    print("[+] Successfully updated settings_repository.dart with fresh credentials!")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        code = sys.argv[1]
    else:
        print("Usage: python3 scripts/exchange_token.py <authorization_code>")
        sys.exit(1)

    exchange_code(code)

