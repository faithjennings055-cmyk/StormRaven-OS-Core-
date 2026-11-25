#!/usr/bin/env bash
# =============================================================================
# verify-asc-credentials.sh — prove an App Store Connect API key works BEFORE
# a build burns 6 minutes on a macOS runner and fails at archive.
#
# Why this exists: on 2026-11-25 a signing run stored four secrets, chose the
# right code path, then Apple refused the credential pair with
#   401 NOT_AUTHORIZED on listTeams.action
# Nothing in the build log said WHICH part was wrong. This script answers that
# in ~5 seconds, on any machine, with no Xcode and no macOS.
#
# Usage:
#   ./verify-asc-credentials.sh --key AuthKey_XXXX.p8 --issuer <uuid> [--key-id XXXX]
#
#   --key       path to the .p8 downloaded from App Store Connect
#   --issuer    Issuer ID (UUID at the top of Integrations, above the key list)
#   --key-id    10-char Key ID. Optional: inferred from the filename if absent.
#   --json      machine-readable output
#   --set-secrets   after a PASS, store the values as GitHub repo secrets
#                   (APPLE_ASC_KEY_ID / APPLE_ASC_ISSUER_ID /
#                    APPLE_ASC_KEY_P8_BASE64) via the gh CLI
#   --repo      owner/name for --set-secrets (default: this repo's origin)
#
# Exit codes:  0 = pair works   1 = pair rejected   2 = bad usage/inputs
# =============================================================================
set -euo pipefail

KEY="" ; ISSUER="" ; KEY_ID="" ; JSON=0 ; SET_SECRETS=0 ; REPO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --key)     KEY="${2:-}"; shift 2 ;;
    --issuer)  ISSUER="${2:-}"; shift 2 ;;
    --key-id)  KEY_ID="${2:-}"; shift 2 ;;
    --json)    JSON=1; shift ;;
    --set-secrets) SET_SECRETS=1; shift ;;
    --repo)    REPO="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

fail_usage() { echo "[FAIL] $1" >&2; exit 2; }

[ -n "$KEY" ]    || fail_usage "--key is required (path to AuthKey_XXXX.p8)"
[ -n "$ISSUER" ] || fail_usage "--issuer is required (UUID above the key list)"
[ -f "$KEY" ]    || fail_usage "key file not found: $KEY"

# --- shape checks before we even talk to Apple -------------------------------
# A wrong-shaped Issuer ID produces the same 401 as a revoked key, so catching
# it here is what turns a mystery into a one-line fix.
if ! printf '%s' "$ISSUER" | grep -qE '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'; then
  fail_usage "issuer '$ISSUER' is not a UUID. Copy it from ABOVE the key list on the Integrations page, not from a key row."
fi

if [ -z "$KEY_ID" ]; then
  base="$(basename "$KEY")"
  KEY_ID="$(printf '%s' "$base" | sed -n 's/^AuthKey_\([A-Z0-9]\{10\}\)\.p8$/\1/p')"
fi
[ -n "$KEY_ID" ] || fail_usage "could not infer Key ID from filename; pass --key-id"

if ! printf '%s' "$KEY_ID" | grep -qE '^[A-Z0-9]{10}$'; then
  fail_usage "key id '$KEY_ID' is not 10 uppercase alphanumerics"
fi

if ! grep -q 'BEGIN PRIVATE KEY' "$KEY" 2>/dev/null; then
  fail_usage "$KEY is not a PEM private key (expected 'BEGIN PRIVATE KEY'). Did you download the .p8 itself, not an HTML page?"
fi

if command -v openssl >/dev/null 2>&1; then
  if ! openssl pkey -in "$KEY" -noout >/dev/null 2>&1; then
    fail_usage "$KEY does not parse as a private key (truncated or wrong file)"
  fi
  if ! openssl pkey -in "$KEY" -noout -text 2>/dev/null | head -1 | grep -qi '256 bit'; then
    fail_usage "$KEY is not a P-256 key. App Store Connect keys are always 256-bit EC."
  fi
fi

# --- build the JWT Apple expects -------------------------------------------
# Header: alg ES256, kid = Key ID, typ JWT
# Claims: iss = Issuer ID, iat now, exp <= 20 min, aud = appstoreconnect-v1
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

now=$(date +%s)
exp=$((now + 600))

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

hdr_json='{"alg":"ES256","kid":"'"$KEY_ID"'","typ":"JWT"}'
pay_json='{"iss":"'"$ISSUER"'","iat":'"$now"',"exp":'"$exp"',"aud":"appstoreconnect-v1"}'

hdr_b64=$(printf '%s' "$hdr_json" | b64url)
pay_b64=$(printf '%s' "$pay_json" | b64url)
signing_input="${hdr_b64}.${pay_b64}"
printf '%s' "$signing_input" > "$WORK/si.txt"

openssl dgst -sha256 -sign "$KEY" -out "$WORK/sig.der" "$WORK/si.txt" 2>/dev/null \
  || fail_usage "signing failed with $KEY"

# JWS ES256 wants raw r||s (64 bytes), not OpenSSL's DER SEQUENCE.
python3 - "$WORK/sig.der" "$WORK/sig.raw" <<'PY'
import sys
d = open(sys.argv[1], 'rb').read()
if d[0] != 0x30:
    sys.exit("unexpected signature encoding")
i = 2 if d[1] < 0x80 else 3
rlen = d[i + 1]
r = int.from_bytes(d[i + 2:i + 2 + rlen], 'big')
j = i + 2 + rlen + 2
slen = d[j - 1]
s = int.from_bytes(d[j:j + slen], 'big')
open(sys.argv[2], 'wb').write(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))
PY

sig_b64=$(b64url < "$WORK/sig.raw")
TOKEN="${signing_input}.${sig_b64}"

# --- ask Apple --------------------------------------------------------------
# /v1/apps is the cheapest authenticated read available. It needs no specific
# app, so it isolates "are these credentials real" from "does this app exist".
resp_file="$WORK/resp.json"
code=$(curl -s -o "$resp_file" -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.appstoreconnect.apple.com/v1/apps?limit=1" 2>/dev/null || echo 000)

emit() { # status message hint
  if [ "$JSON" -eq 1 ]; then
    printf '{"ok":%s,"http":%s,"key_id":"%s","issuer":"%s","message":"%s","hint":"%s"}\n' \
      "$1" "$code" "$KEY_ID" "$ISSUER" "$2" "$3"
  else
    echo "$2"
    [ -n "$3" ] && echo "  -> $3"
  fi
}

case "$code" in
  200)
    emit true  "[PASS] Credential pair works. Key $KEY_ID + issuer $ISSUER authenticate against App Store Connect."
    if [ "$SET_SECRETS" -eq 1 ]; then
      echo ""
      echo "==> Storing secrets in ${REPO:-<this repo>}"
      command -v gh >/dev/null 2>&1 || { echo "[FAIL] gh CLI not installed; cannot set secrets." >&2; exit 1; }
      if [ -z "$REPO" ]; then
        REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
      fi
      [ -n "$REPO" ] || { echo "[FAIL] could not determine repo; pass --repo owner/name" >&2; exit 1; }

      # Only ever written after Apple confirmed the pair. A dead key in a repo
      # secret is worse than a missing one: the build looks configured and then
      # fails at archive with a 401 that says nothing about the cause.
      gh secret set APPLE_ASC_KEY_ID     -R "$REPO" --body "$KEY_ID"
      gh secret set APPLE_ASC_ISSUER_ID  -R "$REPO" --body "$ISSUER"
      base64 -w0 < "$KEY" | gh secret set APPLE_ASC_KEY_P8_BASE64 -R "$REPO"
      if [ -n "${APPLE_TEAM_ID:-}" ]; then
        gh secret set APPLE_TEAM_ID -R "$REPO" --body "$APPLE_TEAM_ID"
      else
        echo "    (APPLE_TEAM_ID not set: export it first if the repo needs it)"
      fi
      echo "==> Secrets stored. Trigger the build with:"
      echo "    gh workflow run ios-signed-ipa.yml -R $REPO"
    fi
    exit 0 ;;
  401)
    hint="Apple rejected the pair. Check, in this order: (1) the key row on Integrations still says Active, not Revoked (2) the key's role is Admin or App Manager (3) the Issuer ID was copied from above the key list."
    emit false "[FAIL] 401 NOT_AUTHORIZED. Apple rejected this key + issuer pair." "$hint"
    exit 1 ;;
  403)
    emit false "[FAIL] 403 FORBIDDEN. The key authenticated but its role cannot read apps. Needs Admin or App Manager." ""
    exit 1 ;;
  000)
    emit false "[FAIL] Could not reach api.appstoreconnect.apple.com (network blocked?)" ""
    exit 1 ;;
  *)
    msg="[FAIL] unexpected HTTP $code from App Store Connect."
    emit false "$msg" "$(head -c 300 "$resp_file" 2>/dev/null | tr -d '\n')"
    exit 1 ;;
esac
