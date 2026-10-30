#!/usr/bin/env python3
"""Put MAIN/LAUNCHER on GodotApp and drop the GodotAppLauncher alias.

Godot 4.7's Gradle template (and the debug/release overlays it rewrites on
every export) keep MAIN/LAUNCHER only on an activity-alias. Nothing OS /
some PackageInstaller paths are picky about aliases; a single exported
activity is the sideload-safe shape.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

LAUNCHER = """
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
"""

ALIAS_RE = re.compile(
    r"\s*<activity-alias\b[^>]*GodotAppLauncher[\s\S]*?</activity-alias>\s*",
    re.IGNORECASE,
)


def patch_text(text: str) -> str:
    text = text.replace('android:exported="false"', 'android:exported="true"')
    text = text.replace(
        'android:screenOrientation="reversePortrait"',
        'android:screenOrientation="portrait"',
    )
    text = text.replace(
        'android:screenOrientation="landscape"',
        'android:screenOrientation="portrait"',
    )
    text = text.replace(
        'android:screenOrientation="reverseLandscape"',
        'android:screenOrientation="portrait"',
    )
    text = ALIAS_RE.sub("\n", text)

    if "android.intent.action.MAIN" in text and "GodotApp" in text:
        # Intent-filter already present (on GodotApp after alias removal).
        if 'android:name=".GodotApp"' in text or 'android:name="com.godot.game.GodotApp"' in text:
            return text

    # Self-closing GodotApp activity → open tag with launcher filter.
    self_closing = re.compile(
        r"(<activity\b(?=[^>]*GodotApp)[^>]*?)/>",
        re.IGNORECASE | re.DOTALL,
    )

    def open_activity(match: re.Match) -> str:
        open_tag = match.group(1).rstrip()
        if "android:exported" not in open_tag:
            open_tag += '\n            android:exported="true"'
        return open_tag + ">" + LAUNCHER + "        </activity>"

    new, n = self_closing.subn(open_activity, text, count=1)
    if n:
        return new

    # Already an open <activity ... GodotApp> ... </activity> without filter.
    open_act = re.compile(
        r"(<activity\b(?=[^>]*GodotApp)[^>]*>)([\s\S]*?)(</activity>)",
        re.IGNORECASE,
    )

    def inject(match: re.Match) -> str:
        inner = match.group(2)
        if "android.intent.action.MAIN" in inner:
            return match.group(0)
        return match.group(1) + inner + LAUNCHER + "        " + match.group(3)

    new, n = open_act.subn(inject, text, count=1)
    return new if n else text


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    changed = 0
    for path in root.rglob("AndroidManifest.xml"):
        if "build/intermediates" in str(path) or "build/outputs" in str(path):
            continue
        original = path.read_text(encoding="utf-8")
        updated = patch_text(original)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            print("Patched", path)
            changed += 1
        else:
            print("Unchanged", path)
    print(f"Manifests patched: {changed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
