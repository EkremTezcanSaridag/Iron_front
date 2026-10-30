#!/usr/bin/env bash
# Clean Godot 4.7.2 Gradle debug APK export (no apktool / no classic-template patching).
#
# Why Gradle + 4.7.2:
#   Godot 4.3's classic template is rejected on modern Android (duplicate
#   provider authorities) and its prebuilt .so files are 4 KB ELF-aligned,
#   which Android 15+ 16 KB page-size devices refuse.
#   4.7.2 ships 16 KB-aligned arm64/x86_64 libs, AGP 8.6.1, compile/targetSdk 36.
#
# Phone APK is arm64-v8a only. armeabi-v7a is omitted because those libs are
# still 4 KB ELF-aligned. Enable architectures/x86_64 in export_presets.cfg
# if you need an x86_64 emulator build.
#
# Requires: Godot 4.7.2, OpenJDK 17, Android SDK (platform 36, build-tools
# 36.1.0, NDK 29.0.14206865), and the Android build template at android/build.
#
# Godot's Gradle copy step fails on some FUSE artifact mounts (~100 MB limit),
# so we always export to /tmp and then copy to the requested path.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$ROOT/Siginak-v0.2.0-debug.apk}"
GODOT="${GODOT:-$ROOT/tools/Godot_v4.7.2-stable_linux.x86_64}"
ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$ROOT/tools/android-sdk}}"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
export ANDROID_HOME="$ANDROID_SDK"
export ANDROID_SDK_ROOT="$ANDROID_SDK"
export PATH="$JAVA_HOME/bin:$PATH"
KEYSTORE="${DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"
TEMPLATES="${GODOT_TEMPLATES:-$HOME/.local/share/godot/export_templates/4.7.2.stable}"

if [[ ! -x "$GODOT" ]]; then
  echo "Godot 4.7.2 not found at $GODOT" >&2
  exit 1
fi
if [[ ! -d "$ANDROID_SDK/platforms/android-36" ]]; then
  echo "Android SDK platform 36 missing under $ANDROID_SDK" >&2
  exit 1
fi
if [[ ! -f "$KEYSTORE" ]]; then
  mkdir -p "$(dirname "$KEYSTORE")"
  keytool -genkeypair -keystore "$KEYSTORE" -alias androiddebugkey \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass android -keypass android \
    -dname "CN=Android Debug,O=Android,C=US"
fi

# Install Gradle template if needed
if [[ ! -f "$ROOT/android/build/build.gradle" ]]; then
  if [[ ! -f "$TEMPLATES/android_source.zip" ]]; then
    echo "Missing $TEMPLATES/android_source.zip" >&2
    exit 1
  fi
  mkdir -p "$ROOT/android/build"
  unzip -q -o "$TEMPLATES/android_source.zip" -d "$ROOT/android/build"
  touch "$ROOT/android/build/.gdignore"
fi
echo "4.7.2.stable" > "$ROOT/android/.build_version"
# Keep Godot from importing the SDK tree as project files.
mkdir -p "$ROOT/tools"
touch "$ROOT/tools/.gdignore"

# Make the real activity exported so `am start -n .../GodotApp` works on API 36.
# Godot 4.7 puts MAIN/LAUNCHER only on an activity-alias; TCG emulators often
# fail to resolve the alias ("Activity class does not exist").
python3 - "$ROOT/android/build" <<'PY'
from pathlib import Path
import re, sys
root = Path(sys.argv[1])
for rel in ["src/main/AndroidManifest.xml", "src/debug/AndroidManifest.xml"]:
    p = root / rel
    if not p.exists():
        continue
    text = p.read_text(encoding="utf-8")
    text = text.replace('android:exported="false"', 'android:exported="true"')
    text = text.replace('android:screenOrientation="reversePortrait"', 'android:screenOrientation="portrait"')
    text = text.replace('android:screenOrientation="landscape"', 'android:screenOrientation="portrait"')
    text = text.replace('android:screenOrientation="reverseLandscape"', 'android:screenOrientation="portrait"')
    p.write_text(text, encoding="utf-8")
    print("Patched", p)
PY

# Point Godot 4.7 editor settings at JDK 17 + this SDK
SETTINGS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
mkdir -p "$SETTINGS_DIR"
# First launch creates the versioned settings file if needed.
"$GODOT" --headless --path "$ROOT" --quit >/dev/null 2>&1 || true
SETTINGS="$(ls -1 "$SETTINGS_DIR"/editor_settings-4*.tres 2>/dev/null | tail -1 || true)"
if [[ -n "$SETTINGS" ]]; then
  python3 - "$SETTINGS" "$ANDROID_SDK" "$JAVA_HOME" "$KEYSTORE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
replacements = {
    "export/android/android_sdk_path": sys.argv[2],
    "export/android/java_sdk_path": sys.argv[3],
    "export/android/debug_keystore": sys.argv[4],
    "export/android/debug_keystore_user": "androiddebugkey",
    "export/android/debug_keystore_pass": "android",
}
import re
for key, val in replacements.items():
    if f'{key} = "' in text:
        text = re.sub(rf'{re.escape(key)} = ".*"', f'{key} = "{val}"', text)
    else:
        text = text.rstrip() + f'\n{key} = "{val}"\n'
p.write_text(text, encoding="utf-8")
print(f"Updated {p}")
PY
fi

TMP_APK="$(mktemp /tmp/Siginak-gradle-XXXXXX.apk)"
cleanup() { rm -f "$TMP_APK"; }
trap cleanup EXIT

echo "==> Godot 4.7.2 Gradle debug export -> $TMP_APK (then copy to $OUT)"
"$GODOT" --headless --path "$ROOT" --export-debug "Android" "$TMP_APK"

mkdir -p "$(dirname "$OUT")"
if ! cp -f "$TMP_APK" "$OUT"; then
  echo "WARNING: copy to $OUT failed (FUSE size limit?). Leaving APK at $TMP_APK" >&2
  trap - EXIT
  OUT="$TMP_APK"
else
  echo "Copied $(stat -c%s "$OUT") bytes to $OUT"
fi

echo "==> Verify"
BT=""
for cand in "$ANDROID_SDK"/build-tools/36.1.0 "$ANDROID_SDK"/build-tools/35.0.1 "$ANDROID_SDK"/build-tools/34.0.0; do
  if [[ -x "$cand/apksigner" ]]; then BT="$cand"; break; fi
done
if [[ -z "$BT" ]]; then
  echo "apksigner not found under $ANDROID_SDK/build-tools" >&2
  exit 1
fi

"$BT/apksigner" verify --verbose --print-certs "$OUT"
echo "==> zipalign -P 16 (Android 15+ 16 KB page size)"
"$BT/zipalign" -c -P 16 -v 4 "$OUT" | tail -5
"$BT/aapt" dump badging "$OUT" 2>/dev/null | grep -E "package:|sdkVersion|targetSdkVersion|native-code" || true
if [[ -x "$BT/aapt2" ]]; then
  "$BT/aapt2" dump xmltree "$OUT" --file AndroidManifest.xml | grep -A 5 "E: provider" || true
fi

python3 - "$OUT" <<'PY'
"""Fail if any packaged ELF PT_LOAD alignment is below 16 KB."""
import struct, sys, zipfile, io
apk = sys.argv[1]
min_ok = 0x4000
bad = []
with zipfile.ZipFile(apk) as z:
    for info in z.infolist():
        if not info.filename.endswith(".so"):
            continue
        data = z.read(info.filename)
        if data[:4] != b"\x7fELF":
            bad.append((info.filename, "not ELF"))
            continue
        ei_class = data[4]
        if ei_class == 2:
            e_phoff = struct.unpack_from("<Q", data, 32)[0]
            e_phentsize = struct.unpack_from("<H", data, 54)[0]
            e_phnum = struct.unpack_from("<H", data, 56)[0]
        else:
            e_phoff = struct.unpack_from("<I", data, 28)[0]
            e_phentsize = struct.unpack_from("<H", data, 42)[0]
            e_phnum = struct.unpack_from("<H", data, 44)[0]
        aligns = []
        for i in range(e_phnum):
            off = e_phoff + i * e_phentsize
            p_type = struct.unpack_from("<I", data, off)[0]
            if p_type != 1:
                continue
            p_align = (
                struct.unpack_from("<Q", data, off + 48)[0]
                if ei_class == 2
                else struct.unpack_from("<I", data, off + 28)[0]
            )
            aligns.append(p_align)
        mx = max(aligns) if aligns else 0
        status = "OK" if mx >= min_ok else "FAIL"
        print(f"  {info.filename}: max PT_LOAD Align=0x{mx:x} {status}")
        if mx < min_ok:
            bad.append((info.filename, hex(mx)))
if bad:
    sys.exit(f"Native libs not 16 KB aligned: {bad}")
print("All native libs have PT_LOAD Align >= 0x4000")
PY

ls -lh "$OUT"
echo "Wrote $OUT"
