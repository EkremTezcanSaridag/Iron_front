#!/usr/bin/env bash
# Export a debug-signed Android APK that current Android versions will install.
#
# Godot 4.3's classic (non-Gradle) APK template export produces a package that
# PackageManager on Android 11+ rejects as invalid ("Paket geçersiz..."). Two
# bugs in the merged binary manifest:
#   1. FileProvider and InitializationProvider share the same android:authorities
#   2. vulkan uses-feature attributes are encoded as strings, not typed values
# This script exports with Godot, then rebuilds the manifest with apktool so
# authorities are unique and attributes are correctly typed, then zipaligns and
# signs with apksigner (v1+v2+v3).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$ROOT/IronFronts-v0.1.1-debug.apk}"
GODOT="${GODOT:-$ROOT/tools/Godot_v4.3-stable_linux.x86_64}"
ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$ROOT/tools/android-sdk}}"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"
export ANDROID_HOME="$ANDROID_SDK"
export ANDROID_SDK_ROOT="$ANDROID_SDK"
BUILD_TOOLS="$ANDROID_SDK/build-tools/34.0.0"
APKTOOL_JAR="${APKTOOL_JAR:-$ROOT/tools/apktool.jar}"
KEYSTORE="${DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"

if [[ ! -x "$GODOT" ]]; then
  echo "Godot binary not found at $GODOT" >&2
  exit 1
fi
if [[ ! -x "$BUILD_TOOLS/apksigner" || ! -x "$BUILD_TOOLS/zipalign" ]]; then
  echo "Android build-tools 34.0.0 not found under $ANDROID_SDK" >&2
  exit 1
fi
if [[ ! -f "$KEYSTORE" ]]; then
  mkdir -p "$(dirname "$KEYSTORE")"
  keytool -genkeypair -v -keystore "$KEYSTORE" -alias androiddebugkey \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass android -keypass android \
    -dname "CN=Android Debug,O=Android,C=US"
fi
if [[ ! -f "$APKTOOL_JAR" ]]; then
  mkdir -p "$(dirname "$APKTOOL_JAR")"
  curl -fsSL -o "$APKTOOL_JAR" \
    https://github.com/iBotPeaches/Apktool/releases/download/v2.9.3/apktool_2.9.3.jar
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
RAW="$WORKDIR/raw.apk"
DECODED="$WORKDIR/decoded"
REBUILT="$WORKDIR/rebuilt.apk"
ALIGNED="$WORKDIR/aligned.apk"

echo "==> Godot classic debug export"
"$GODOT" --headless --path "$ROOT" --export-debug "Android" "$RAW"

echo "==> Decode APK and fix manifest"
java -jar "$APKTOOL_JAR" d -f "$RAW" -o "$DECODED"
python3 - "$DECODED/AndroidManifest.xml" <<'PY'
import re, sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
# Godot classic export copies the FileProvider authority onto InitializationProvider.
new, n = re.subn(
    r'<provider android:authorities="([^"]+)\.fileprovider" android:exported="false" android:name="androidx\.startup\.InitializationProvider">',
    r'<provider android:authorities="\1.androidx-startup" android:exported="false" android:name="androidx.startup.InitializationProvider">',
    text,
    count=1,
)
if n != 1:
    sys.exit(f"Expected to rewrite 1 InitializationProvider authority, rewrote {n}")
path.write_text(new, encoding="utf-8")
print("Rewrote InitializationProvider authority to unique androidx-startup value")
PY

echo "==> Rebuild, zipalign, apksigner (v1+v2+v3)"
java -jar "$APKTOOL_JAR" b "$DECODED" -o "$REBUILT"
"$BUILD_TOOLS/zipalign" -f -p 4 "$REBUILT" "$ALIGNED"
"$BUILD_TOOLS/apksigner" sign \
  --ks "$KEYSTORE" \
  --ks-key-alias androiddebugkey \
  --ks-pass pass:android \
  --key-pass pass:android \
  --v1-signing-enabled true \
  --v2-signing-enabled true \
  --v3-signing-enabled true \
  --out "$OUT" \
  "$ALIGNED"

echo "==> Verify"
"$BUILD_TOOLS/apksigner" verify --verbose --print-certs "$OUT"
"$BUILD_TOOLS/zipalign" -c -v 4 "$OUT" | tail -3
"$BUILD_TOOLS/aapt" dump xmltree "$OUT" AndroidManifest.xml | grep -A 4 "E: provider"
echo "Wrote $OUT"
