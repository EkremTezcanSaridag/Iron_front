#!/usr/bin/env bash
# Godot 4.7.2 Gradle *release* APK for the phone (arm64-v8a only).
#
# Why this shape (CMF Phone 1 / Nothing OS 3 / Android 16):
#   The Downloads app PackageInstaller maps many failures to
#   "Paket geçersiz göründüğünden uygulama yüklenemedi".
#   v0.2.0 was a *debug* APK (debuggable=true, CN=Android Debug, no v3,
#   157 MB with x86_64). adb install on an emulator still accepted it;
#   the phone installer did not.
#   This script builds a non-debuggable, project-keystore, v2+v3,
#   16 KB-aligned, arm64-only APK (~80 MB).
#
# Requires: Godot 4.7.2, OpenJDK 17, Android SDK 36, NDK 29, android/build template.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$ROOT/Siginak-v0.2.1.apk}"
GODOT="${GODOT:-$ROOT/tools/Godot_v4.7.2-stable_linux.x86_64}"
ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$ROOT/tools/android-sdk}}"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
export ANDROID_HOME="$ANDROID_SDK"
export ANDROID_SDK_ROOT="$ANDROID_SDK"
export PATH="$JAVA_HOME/bin:$PATH"

KS_DIR="$ROOT/keystore"
KS="$KS_DIR/siginak-upload.jks"
KS_ALIAS="siginak"
KS_PASS="siginakupload"
TEMPLATES="${GODOT_TEMPLATES:-$HOME/.local/share/godot/export_templates/4.7.2.stable}"

if [[ ! -x "$GODOT" ]]; then
  echo "Godot 4.7.2 not found at $GODOT" >&2
  exit 1
fi
if [[ ! -d "$ANDROID_SDK/platforms/android-36" ]]; then
  echo "Android SDK platform 36 missing under $ANDROID_SDK" >&2
  exit 1
fi

mkdir -p "$KS_DIR"
if [[ ! -f "$KS" ]]; then
  echo "==> Creating project upload keystore $KS"
  keytool -genkeypair -v \
    -keystore "$KS" -storetype PKCS12 \
    -alias "$KS_ALIAS" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$KS_PASS" -keypass "$KS_PASS" \
    -dname "CN=Siginak, OU=Game, O=Siginak, L=Istanbul, C=TR"
fi

# Godot 4.7 reads release keystore from env (and .godot/export_credentials.cfg).
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KS"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$KS_ALIAS"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$KS_PASS"

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
mkdir -p "$ROOT/tools"
touch "$ROOT/tools/.gdignore"

python3 "$ROOT/scripts/patch_android_manifest.py" "$ROOT/android/build"

# Gradle runs *after* Godot rewrites src/debug|release overlays — hook preBuild.
GRADLE="$ROOT/android/build/build.gradle"
MARKER="// --- siginak-manifest-patch ---"
if ! grep -q "$MARKER" "$GRADLE"; then
  cat >> "$GRADLE" <<'GRADLE'

// --- siginak-manifest-patch ---
tasks.matching { it.name == "preBuild" }.configureEach {
    doFirst {
        def script = new File(rootProject.projectDir, "../../scripts/patch_android_manifest.py")
        exec {
            commandLine "python3", script.absolutePath, rootProject.projectDir.absolutePath
        }
    }
}
GRADLE
  echo "Injected preBuild manifest patch into $GRADLE"
fi

SETTINGS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
mkdir -p "$SETTINGS_DIR"
"$GODOT" --headless --path "$ROOT" --quit >/dev/null 2>&1 || true
SETTINGS="$(ls -1 "$SETTINGS_DIR"/editor_settings-4*.tres 2>/dev/null | tail -1 || true)"
if [[ -n "$SETTINGS" ]]; then
  python3 - "$SETTINGS" "$ANDROID_SDK" "$JAVA_HOME" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
replacements = {
    "export/android/android_sdk_path": sys.argv[2],
    "export/android/java_sdk_path": sys.argv[3],
}
for key, val in replacements.items():
    if f'{key} = "' in text:
        text = re.sub(rf'{re.escape(key)} = ".*"', f'{key} = "{val}"', text)
    else:
        text = text.rstrip() + f'\n{key} = "{val}"\n'
p.write_text(text, encoding="utf-8")
print(f"Updated {p}")
PY
fi

CRED="$ROOT/.godot/export_credentials.cfg"
mkdir -p "$ROOT/.godot"
cat > "$CRED" <<EOF
[preset.0]

keystore/debug = ""
keystore/debug_user = ""
keystore/debug_password = ""
keystore/release = "$KS"
keystore/release_user = "$KS_ALIAS"
keystore/release_password = "$KS_PASS"
EOF

TMP_APK="$(mktemp /tmp/Siginak-gradle-XXXXXX.apk)"
UNSIGNED="${TMP_APK}.unsigned.apk"
ALIGNED="${TMP_APK}.aligned.apk"
cleanup() { rm -f "$TMP_APK" "$UNSIGNED" "$ALIGNED"; }
trap cleanup EXIT

echo "==> Godot 4.7.2 Gradle RELEASE export -> $TMP_APK"
"$GODOT" --headless --path "$ROOT" --export-release "Android" "$TMP_APK"

BT=""
for cand in "$ANDROID_SDK"/build-tools/36.1.0 "$ANDROID_SDK"/build-tools/35.0.1 "$ANDROID_SDK"/build-tools/34.0.0; do
  if [[ -x "$cand/apksigner" ]]; then BT="$cand"; break; fi
done
if [[ -z "$BT" ]]; then
  echo "apksigner not found under $ANDROID_SDK/build-tools" >&2
  exit 1
fi

echo "==> zipalign -P 16 + apksigner v2+v3 with project keystore"
# Strip Godot/Gradle signature, realign uncompressed .so to 16 KB, re-sign.
# apksigner preserves 16 KB alignment when signing an already-aligned APK.
cp -f "$TMP_APK" "$UNSIGNED"
# If the APK is already signed, zipalign -f still works on a copy; apksigner
# --overwrite will replace the signature. Align first on a clean unsigned zip
# when possible; otherwise align+resign in place.
"$BT/zipalign" -P 16 -f 4 "$UNSIGNED" "$ALIGNED"
"$BT/apksigner" sign \
  --ks "$KS" --ks-key-alias "$KS_ALIAS" \
  --ks-pass "pass:$KS_PASS" --key-pass "pass:$KS_PASS" \
  --v1-signing-enabled true \
  --v2-signing-enabled true \
  --v3-signing-enabled true \
  --v4-signing-enabled false \
  --min-sdk-version 24 \
  --out "$TMP_APK" \
  "$ALIGNED"

mkdir -p "$(dirname "$OUT")"
if ! cp -f "$TMP_APK" "$OUT"; then
  echo "WARNING: copy to $OUT failed (FUSE size limit?). Leaving APK at $TMP_APK" >&2
  trap - EXIT
  OUT="$TMP_APK"
else
  echo "Copied $(stat -c%s "$OUT") bytes to $OUT"
fi

echo "==> Verify"
"$BT/apksigner" verify --verbose --print-certs "$OUT"
echo "==> zipalign -P 16 (Android 15+ 16 KB page size)"
"$BT/zipalign" -c -P 16 -v 4 "$OUT" | tail -8
"$BT/aapt" dump badging "$OUT" 2>/dev/null | grep -E "package:|sdkVersion|targetSdkVersion|native-code|application-debuggable" || true
if [[ -x "$BT/aapt2" ]]; then
  echo "==> launcher + debuggable"
  "$BT/aapt2" dump xmltree "$OUT" --file AndroidManifest.xml \
    | grep -E "debuggable|testOnly|GodotApp|LAUNCHER|MAIN|activity-alias|extractNativeLibs" || true
fi

python3 - "$OUT" <<'PY'
"""Fail if any packaged ELF is not 16 KB PT_LOAD aligned, or if a non-arm64 .so slips in."""
import struct, sys, zipfile
apk = sys.argv[1]
min_ok = 0x4000
bad = []
abis = set()
with zipfile.ZipFile(apk) as z:
    so_files = [i for i in z.infolist() if i.filename.endswith(".so")]
    if not so_files:
        sys.exit("No native libs in APK")
    for info in so_files:
        parts = info.filename.split("/")
        if len(parts) >= 3 and parts[0] == "lib":
            abis.add(parts[1])
        if info.compress_type != 0:
            bad.append((info.filename, f"compressed({info.compress_type})"))
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
        print(f"  {info.filename}: max PT_LOAD Align=0x{mx:x} {status} zip={info.compress_type}")
        if mx < min_ok:
            bad.append((info.filename, hex(mx)))
print("ABIs:", sorted(abis))
if abis != {"arm64-v8a"}:
    sys.exit(f"Phone APK must be arm64-v8a only, got {abis}")
if bad:
    sys.exit(f"Native libs not 16 KB aligned / uncompressed: {bad}")
print("All native libs arm64-v8a, uncompressed, PT_LOAD Align >= 0x4000")
PY

ls -lh "$OUT"
echo "Wrote $OUT"
