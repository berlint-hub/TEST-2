#!/usr/bin/env bash
# Inject a self-built libemucore.so into an AetherSX2 / NetherSX2 APK,
# zipalign it and sign it — the same procedure as documented by Tahlreth
# in the AetherSX2 LGPL release.
#
# Usage:
#   inject_and_sign.sh <input.apk> <libemucore.so> <output.apk>
#
# Environment (all optional):
#   BUILD_TOOLS   dir containing zipalign/apksigner
#                 (default: newest dir in $ANDROID_HOME/build-tools)
#   KEYSTORE      path to an existing keystore (default: generate a throwaway one)
#   KEYSTORE_PASS keystore password (default: "android")
#   KEY_ALIAS     key alias (default: "androiddebugkey")
#
# Note: the output APK is signed with a different key than the original, so
# you must uninstall the previously installed app before installing it.

set -euo pipefail

if [ $# -ne 3 ]; then
    grep '^# Usage' -A2 "$0" | sed 's/^# \?//'
    exit 1
fi

INPUT_APK="$(readlink -f "$1")"
CORE_SO="$(readlink -f "$2")"
OUTPUT_APK="$3"
[ -f "$INPUT_APK" ] || { echo "error: $INPUT_APK not found" >&2; exit 1; }
[ -f "$CORE_SO" ]   || { echo "error: $CORE_SO not found" >&2; exit 1; }

# --- locate Android build tools ------------------------------------------
if [ -z "${BUILD_TOOLS:-}" ]; then
    SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
    if [ -n "$SDK_ROOT" ] && [ -d "$SDK_ROOT/build-tools" ]; then
        BUILD_TOOLS="$(ls -d "$SDK_ROOT"/build-tools/* | sort -V | tail -1)"
    fi
fi
ZIPALIGN="${BUILD_TOOLS:+$BUILD_TOOLS/}zipalign"
APKSIGNER="${BUILD_TOOLS:+$BUILD_TOOLS/}apksigner"
command -v "$ZIPALIGN" >/dev/null || ZIPALIGN="$(command -v zipalign || true)"
command -v "$APKSIGNER" >/dev/null || APKSIGNER="$(command -v apksigner || true)"
[ -x "$ZIPALIGN" ]  || { echo "error: zipalign not found (set BUILD_TOOLS)" >&2; exit 1; }
[ -x "$APKSIGNER" ] || { echo "error: apksigner not found (set BUILD_TOOLS)" >&2; exit 1; }
echo "using build tools: $ZIPALIGN / $APKSIGNER"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# --- inject the library (zip -0 => STORE, aapt would compress it) --------
cp "$INPUT_APK" "$WORKDIR/app.apk"
mkdir -p "$WORKDIR/lib/arm64-v8a"
cp "$CORE_SO" "$WORKDIR/lib/arm64-v8a/libemucore.so"
( cd "$WORKDIR" && zip -0 app.apk lib/arm64-v8a/libemucore.so )
echo "injected libemucore.so into apk"

# --- zipalign (4-byte boundary, page-align native libs) ------------------
( cd "$WORKDIR" && "$ZIPALIGN" -p -f 4 app.apk aligned.apk )
echo "zipaligned"

# --- signing key ---------------------------------------------------------
KEYSTORE="${KEYSTORE:-}"
if [ -z "$KEYSTORE" ]; then
    KEYSTORE="$WORKDIR/libemucore-ci.keystore"
    KEYSTORE_PASS="${KEYSTORE_PASS:-android}"
    KEY_ALIAS="${KEY_ALIAS:-androiddebugkey}"
    keytool -genkeypair -v \
        -keystore "$KEYSTORE" -storepass "$KEYSTORE_PASS" -keypass "$KEYSTORE_PASS" \
        -alias "$KEY_ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=libemucore-ci, OU=Personal, O=Personal, C=ZZ" >/dev/null 2>&1
    echo "generated throwaway keystore"
else
    KEYSTORE_PASS="${KEYSTORE_PASS:-android}"
    KEY_ALIAS="${KEY_ALIAS:-androiddebugkey}"
fi

# --- sign + verify -------------------------------------------------------
mkdir -p "$(dirname "$OUTPUT_APK")"
"$APKSIGNER" sign \
    --ks "$KEYSTORE" --ks-pass "pass:$KEYSTORE_PASS" --ks-key-alias "$KEY_ALIAS" \
    --out "$OUTPUT_APK" "$WORKDIR/aligned.apk"
"$APKSIGNER" verify --print-certs "$OUTPUT_APK" | head -3
echo "OK: $OUTPUT_APK"
