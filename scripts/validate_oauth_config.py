#!/usr/bin/env python3
"""Validate private OAuth build credentials without printing secret values."""

import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


CONFIG_PATH = Path(sys.argv[1] if len(sys.argv) > 1 else "oauth_secrets.json")
REQUIRED = (
    "GOOGLE_OAUTH_CLIENT_ID",
    "GOOGLE_OAUTH_CLIENT_SECRET",
    "GOOGLE_REFRESH_TOKEN",
)


def fail(message: str) -> None:
    raise SystemExit(f"OAuth validation failed: {message}")


if not CONFIG_PATH.is_file():
    fail(f"{CONFIG_PATH} does not exist")

try:
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as error:
    fail(f"invalid JSON: {error}")

missing = [key for key in REQUIRED if not str(config.get(key, "")).strip()]
if missing:
    fail("missing values: " + ", ".join(missing))

values = {key: str(config[key]).strip() for key in REQUIRED}
for key, value in values.items():
    if value[0:1] in {'"', "'"} or value[-1:] in {'"', "'"}:
        fail(f"{key} contains surrounding quote characters")

token_body = urllib.parse.urlencode(
    {
        "client_id": values["GOOGLE_OAUTH_CLIENT_ID"],
        "client_secret": values["GOOGLE_OAUTH_CLIENT_SECRET"],
        "refresh_token": values["GOOGLE_REFRESH_TOKEN"],
        "grant_type": "refresh_token",
    }
).encode("utf-8")

try:
    request = urllib.request.Request(
        "https://oauth2.googleapis.com/token",
        data=token_body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        token_data = json.load(response)
except urllib.error.HTTPError as error:
    try:
        details = json.load(error)
        reason = details.get("error_description") or details.get("error")
    except Exception:
        reason = f"HTTP {error.code}"
    fail(f"refresh-token exchange rejected: {reason}")
except (OSError, TimeoutError, json.JSONDecodeError) as error:
    fail(f"token endpoint unavailable: {error}")

access_token = token_data.get("access_token")
if not access_token:
    fail("token endpoint returned no access token")

try:
    token_info_url = "https://oauth2.googleapis.com/tokeninfo?" + urllib.parse.urlencode(
        {"access_token": access_token}
    )
    with urllib.request.urlopen(token_info_url, timeout=20) as response:
        token_info = json.load(response)
    scopes = set(str(token_info.get("scope", "")).split())
    required_scope = "https://www.googleapis.com/auth/drive.file"
    if required_scope not in scopes:
        fail(f"refresh token is missing required scope: {required_scope}")

    drive_request = urllib.request.Request(
        "https://www.googleapis.com/drive/v3/about?fields=user(permissionId)",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    with urllib.request.urlopen(drive_request, timeout=20) as response:
        drive_data = json.load(response)
    if not drive_data.get("user", {}).get("permissionId"):
        fail("Drive API did not return an authenticated user")
except urllib.error.HTTPError as error:
    fail(f"Drive validation rejected with HTTP {error.code}")
except (OSError, TimeoutError, json.JSONDecodeError) as error:
    fail(f"Drive validation unavailable: {error}")

print("OAuth validation passed: refresh, drive.file scope, and Drive API access are valid.")
