#!/usr/bin/env bash
# =============================================================================
# StormRaven OS — App Store Connect API key preflight validator
# =============================================================================
# Why this exists: we burned three macOS build cycles on a credential pair Apple
# rejected with 401 NOT_AUTHORIZED. A build takes ~90s and tells you almost
# nothing when it fails. This checks the key/issuer pair against Apple in about
# two seconds, before any build is queued.
#
# It proves three things, in order:
#   1. the .p8 parses as an EC P-256 private key
#   2. a JWT can be signed with it (ES256, kid header, appstoreconnect-v1 aud)
#   3. Apple accepts that JWT against the App Store Connect API
#
# Usage:
#   ./validate-asc-key.sh --key AuthKey_XXXX.p8 --key-id XXXX --issuer <uuid>
#   ./validate-asc-key.sh ... --set-secrets --repo owner/repo   # also writes repo secrets
#
# Exit codes: 0 valid, 1 key unreadable, 2 signing failed, 3 Apple rejected
# =============================================================================
set -euo pipefail

KEY_FILE=""
KEY_ID=""
ISSUER_ID=""
SET_SECRETS=0
REPO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --key)        KEY_FILE="${2:-}"; shift 2 ;;
    --key-id)     KEY_ID="${2:-}"; shift 2 ;;
    --issuer)     ISSUER_ID="${2:-}"; shift 2 ;;
    --set-secrets) SET_SECRETS=1; shift ;;
    --repo)       REPO="${2:-}"; shift 2 ;;
    -h|--help)    sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 64 ;;
  esac
done

die() { echo "[FAIL] $*" >&2; exit "${EXIT_CODE:-1}"; }

[ -n "$KEY_FILE" ] || die "--key <path/to/AuthKey_XXXX.p8> is required"
[ -n "$KEY_ID" ]   || die "--key-id <10-char key id> is required"
[ -n "$ISSUER_ID" ] || die "--issuer <uuid from top of Integrations page> is required"
[ -r "$KEY_FILE" ] || { EXIT_CODE=1; die "cannot read $KEY_FILE"; }

# --- 1. is it a real EC P-256 private key? -----------------------------------
if command -v openssl >/dev/null 2>&1; then
  if ! openssl pkey -in "$KEY_FILE" -noout 2>/dev/null; then
    EXIT_CODE=1; die "$KEY_FILE is not a readable private key"
  fi
  CURVE="$(openssl pkey -in "$KEY_FILE" -noout -text 2>/dev/null | head -n 1)"
  echo "[ok] key parses: ${CURVE}"
else
  echo "[warn] openssl not found, skipping structural key check"
fi

# --- 2 & 3. sign an ES256 JWT and ask Apple ----------------------------------
# Apple's API wants a JWT signed ES256, with a kid header, an iss claim, and the
# appstoreconnect-v1 audience. We build it with openssl and convert the DER
# ECDSA signature to the raw 64-byte r||s form JWT requires, so this works with
# no Python packages beyond the standard library.
RESULT="$(python3 - "$KEY_FILE" "$KEY_ID" "$ISSUER_ID" <<'PY'
import base64, json, subprocess, sys, tempfile, os, time, urllib.request

keyfile, kid, issuer = sys.argv[1], sys.argv[2], sys.argv[3]

def b64u(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()

# DER -> raw r||s (JWT ES256 signatures are 64 bytes, never DER)
def der_to_raw(der: bytes) -> bytes:
    if der[0] != 0x30:
        raise ValueError("not a DER sequence")
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        if der[i] != 0x02:
            raise ValueError("expected DER integer")
        i += 1
        ln = der[i]
        i += 1
        val = der[i:i + ln]
        i += ln
        val = val.lstrip(b"\x00")
        out += val.rjust(32, b"\x00")
    return out

now = int(time.time())
header = {"alg": "ES256", "kid": kid, "typ": "JWT"}
payload = {"iss": issuer, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}
signing_input = f"{b64u(json.dumps(header).encode())}.{b64u(json.dumps(payload).encode())}"

with tempfile.TemporaryDirectory() as td:
    msg = os.path.join(td, "in")
    sig = os.path.join(td, "sig.der")
    open(msg, "wb").write(signing_input.encode())
    p = subprocess.run(["openssl", "dgst", "-sha256", "-sign", keyfile, "-out", sig, msg],
                       capture_output=True)
    if p.returncode != 0:
        print("SIGNFAIL " + p.stderr.decode()[:200]); sys.exit(2)
    raw = der_to_raw(open(sig, "rb").read())

token = f"{signing_input}.{b64u(raw)}"

req = urllib.request.Request(
    "https://api.appstoreconnect.apple.com/v1/apps?limit=1",
    headers={"Authorization": f"Bearer {token}"},
)
try:
    resp = urllib.request.urlopen(req, timeout=30)
    body = resp.read().decode()
    print("AUTHORIZED", resp.status, body[:160])
except urllib.error.HTTPError as e:
    print("HTTPERR", e.code, e.read().decode()[:300])
except Exception as e:
    print("NETERR " + str(e)[:200]); sys.exit(2)
PY
)"
EXIT_CODE=$?

echo "$RESULT"
case "$RESULT" in
  AUTHORIZED*)
    echo "[PASS] Apple accepted this key/issuer pair. Safe to run the signing build."
    VALID=1 ;;
  HTTPERR\ 401*|HTTPERR\ 403*)
    echo ""
    echo "[FAIL] Apple rejected the pair (401/403). The key is fine structurally; the credential pair is not."
    echo "       Check, in this order:"
    echo "         1. key row on Integrations says Active, not Revoked/Expired"
    echo "         2. key role is Admin or App Manager"
    echo "         3. Issuer ID is the UUID ABOVE the key list, not from the key row"
    echo "       Re-run this script after fixing - 2 seconds, no build wasted."
    VALID=0 ;;
  *)
    echo "[FAIL] could not validate (signing or network error)." >&2
    VALID=0 ;;
esac

# --- optionally write the repo secrets ---------------------------------------
if [ "$SET_SECRETS" -eq 1 ]; then
  [ -n "$REPO" ] || die "--set-secrets needs --repo owner/repo"
  command -v gh >/dev/null 2>&1 || die "gh CLI not found"
  [ "$VALID" -eq 1 ] || { echo "[skip] not writing secrets for a pair Apple rejected."; exit 3; }
  gh secret set APPLE_ASC_KEY_ID --repo "$REPO" --body "$KEY_ID"
  gh secret set APPLE_ASC_ISSUER_ID --repo "$REPO" --body "$ISSUER_ID"
  gh secret set APPLE_ASC_KEY_P8_BASE64 --repo "$REPO" < <(base64 -w0 "$KEY_FILE")
  gh secret set APPLE_ASC_KEY_P8 --repo "$REPO" < <(base64 -w0 "$KEY_FILE")
  echo "[ok] repo secrets written to $REPO"
fi

[ "$VALID" -eq 1 ] || exit 3
