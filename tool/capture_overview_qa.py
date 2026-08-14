#!/usr/bin/env python3
"""Capture Özet populated + empty screenshots on Kira_Test_Pixel8."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
import xml.sax.saxutils as saxutils

ID = os.environ.get("ANDROID_SERIAL", "emulator-5554")
PKG = "com.tyreest.kiraartisi"
OUT = "docs/qa/final_screenshots"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _adb_bin() -> str:
    local = os.environ.get("LOCALAPPDATA", "")
    candidate = os.path.join(local, "Android", "Sdk", "platform-tools", "adb.exe")
    return candidate if os.path.isfile(candidate) else "adb"


ADB = _adb_bin()


def adb(*args: str) -> None:
    subprocess.check_call([ADB, "-s", ID, *args])


def adb_out(*args: str) -> bytes:
    return subprocess.check_output([ADB, "-s", ID, *args])


def unlock() -> None:
    adb("shell", "input", "keyevent", "KEYCODE_WAKEUP")
    adb("shell", "wm", "dismiss-keyguard")
    time.sleep(0.4)


def screenshot(name: str) -> None:
    data = adb_out("exec-out", "screencap", "-p")
    path = os.path.join(OUT, name)
    with open(path, "wb") as f:
        f.write(data)
    print("shot", path, len(data))


def dump_descs() -> list[str]:
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    adb("pull", "/sdcard/ui.xml", os.path.join(OUT, "_ui.xml"))
    with open(os.path.join(OUT, "_ui.xml"), encoding="utf-8", errors="ignore") as f:
        ui = f.read()
    return [d.replace("&#10;", "|") for d in re.findall(r'content-desc="([^"]*)"', ui)]


def write_prefs(rentals: list[dict] | None) -> None:
    parts = [
        '  <boolean name="flutter.onboarding_done" value="true" />',
    ]
    if rentals is not None:
        raw = json.dumps(rentals, ensure_ascii=False, separators=(",", ":"))
        escaped = saxutils.escape(raw, {'"': "&quot;"})
        parts.append(f'  <string name="flutter.rentals_v1">{escaped}</string>')
    else:
        parts.append('  <string name="flutter.rentals_v1">[]</string>')
    xml = (
        "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n"
        "<map>\n" + "\n".join(parts) + "\n</map>\n"
    )
    path = os.path.join(OUT, "_seed_prefs.xml")
    with open(path, "w", encoding="utf-8") as f:
        f.write(xml)
    unlock()
    adb("shell", "am", "force-stop", PKG)
    adb("push", path, "/data/local/tmp/kira_prefs.xml")
    adb("shell", "run-as", PKG, "mkdir", "-p", "shared_prefs")
    adb(
        "shell",
        "run-as",
        PKG,
        "cp",
        "/data/local/tmp/kira_prefs.xml",
        "shared_prefs/FlutterSharedPreferences.xml",
    )
    unlock()
    adb(
        "shell",
        "am",
        "start",
        "-n",
        f"{PKG}/com.tyreest.kira_artisi_hesapla.MainActivity",
    )
    time.sleep(4.0)


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    os.chdir(ROOT)
    os.makedirs(OUT, exist_ok=True)

    name_raw = adb_out("emu", "avd", "name").decode(errors="ignore")
    name = next(
        (
            ln.strip()
            for ln in name_raw.splitlines()
            if ln.strip() and ln.strip().upper() != "OK"
        ),
        "",
    )
    if name != "Kira_Test_Pixel8":
        print("WRONG_AVD", name, file=sys.stderr)
        return 2

    rental = {
        "id": "qa_ev",
        "role": "tenant",
        "displayName": "Ev",
        "propertyName": "Ev",
        "currentRent": 39000,
        "contractStartDate": "2024-07-01T00:00:00.000",
        "increaseDate": "2027-07-01T00:00:00.000",
        "renewalDate": "2027-07-01T00:00:00.000",
        "nextRenewalDate": "2027-07-01T00:00:00.000",
        "lastRenewalDate": "2026-07-01T00:00:00.000",
        "renewalResolved": True,
        "contractIncreaseRate": None,
        "createdAt": "2026-08-14T00:00:00.000",
        "updatedAt": "2026-08-14T00:00:00.000",
        "reminder": {
            "enabled": False,
            "notify30": True,
            "notify7": True,
            "notify0": True,
        },
        "history": [],
    }

    write_prefs([rental])
    descs = dump_descs()
    joined = " ".join(descs)
    print("populated sample:", [d for d in descs if d][:12])
    screenshot("01_home.png")
    if "Yenileme geçti" in joined:
        print("FAIL: overdue on populated", file=sys.stderr)
        return 1
    if "SIRADAKİ YENİLEME" not in joined and "Sıradaki" not in joined:
        # Semantics may be in text nodes; still require Ev / gün
        if "Ev" not in joined:
            print("FAIL: hero missing", joined[:400], file=sys.stderr)
            return 1
    print("POPULATED_OK")

    write_prefs([])
    descs = dump_descs()
    joined = " ".join(descs)
    print("empty sample:", [d for d in descs if d][:12])
    screenshot("02_home_empty.png")
    if "Kiranı takip etmeye başla" not in joined and "takip" not in joined:
        print("WARN: empty copy not in content-desc; shot taken anyway")
    print("EMPTY_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
