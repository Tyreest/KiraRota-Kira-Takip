#!/usr/bin/env python3
"""Seed Scenario A rental and verify Kiralarım does not show Yenileme geçti."""

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
OUT = "docs/qa/branding"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _adb_bin() -> str:
    env = os.environ.get("ADB")
    if env and os.path.isfile(env):
        return env
    local = os.environ.get("LOCALAPPDATA", "")
    candidate = os.path.join(local, "Android", "Sdk", "platform-tools", "adb.exe")
    if os.path.isfile(candidate):
        return candidate
    return "adb"


ADB = _adb_bin()


def adb(*args: str) -> None:
    subprocess.check_call([ADB, "-s", ID, *args])


def adb_out(*args: str) -> bytes:
    return subprocess.check_output([ADB, "-s", ID, *args])


def dump_ui() -> str:
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    adb("pull", "/sdcard/ui.xml", f"{OUT}/_ui.xml")
    with open(f"{OUT}/_ui.xml", encoding="utf-8", errors="ignore") as f:
        return f.read()


def content_descs(ui: str) -> list[str]:
    return [d.replace("&#10;", "|") for d in re.findall(r'content-desc="([^"]*)"', ui)]


def tap_by_desc_substr(ui: str, needle: str) -> bool:
    for m in re.finditer(r"<node\b[^>]*>", ui):
        chunk = m.group(0)
        if needle not in chunk or "content-desc" not in chunk:
            continue
        bm = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', chunk)
        if not bm:
            continue
        x1, y1, x2, y2 = map(int, bm.groups())
        adb("shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))
        return True
    return False


def screenshot(name: str) -> None:
    data = adb_out("exec-out", "screencap", "-p")
    path = os.path.join(OUT, name)
    with open(path, "wb") as f:
        f.write(data)
    print("shot", path)


def seed_prefs() -> None:
    rentals = [
        {
            "id": "smoke1",
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
            "createdAt": "2026-08-13T00:00:00.000",
            "updatedAt": "2026-08-13T00:00:00.000",
            "reminder": {
                "enabled": False,
                "notify30": True,
                "notify7": True,
                "notify0": True,
            },
            "history": [],
        }
    ]
    raw = json.dumps(rentals, ensure_ascii=False, separators=(",", ":"))
    escaped = saxutils.escape(raw, {'"': "&quot;"})
    xml = (
        "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n"
        "<map>\n"
        '  <boolean name="flutter.onboarding_done" value="true" />\n'
        f'  <string name="flutter.rentals_v1">{escaped}</string>\n'
        "</map>\n"
    )
    prefs_path = os.path.join(OUT, "_seed_prefs.xml")
    with open(prefs_path, "w", encoding="utf-8") as f:
        f.write(xml)

    adb("shell", "am", "force-stop", PKG)
    adb("push", prefs_path, "/data/local/tmp/kira_prefs.xml")
    # Debug builds are run-as capable.
    adb("shell", "run-as", PKG, "mkdir", "-p", "shared_prefs")
    # Copy via run-as after staging in app-accessible path when needed.
    try:
        adb(
            "shell",
            "run-as",
            PKG,
            "cp",
            "/data/local/tmp/kira_prefs.xml",
            "shared_prefs/FlutterSharedPreferences.xml",
        )
    except subprocess.CalledProcessError:
        # Fallback: cat through run-as stdin
        with open(prefs_path, "rb") as f:
            data = f.read()
        proc = subprocess.Popen(
            [
                ADB,
                "-s",
                ID,
                "shell",
                "run-as",
                PKG,
                "sh",
                "-c",
                "cat > shared_prefs/FlutterSharedPreferences.xml",
            ],
            stdin=subprocess.PIPE,
        )
        assert proc.stdin is not None
        proc.stdin.write(data)
        proc.stdin.close()
        if proc.wait() != 0:
            raise RuntimeError("failed to write shared_prefs")
    print("seeded prefs")


def unlock() -> None:
    adb("shell", "input", "keyevent", "KEYCODE_WAKEUP")
    adb("shell", "wm", "dismiss-keyguard")
    time.sleep(0.5)


def wait_for_app(timeout_s: float = 20.0) -> bool:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        try:
            top = adb_out(
                "shell",
                "dumpsys",
                "activity",
                "activities",
            ).decode(errors="ignore")
        except subprocess.CalledProcessError:
            top = ""
        if PKG in top and "MainActivity" in top:
            return True
        time.sleep(1.0)
    return False


def main() -> int:
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
    print("avd", repr(name))
    if name != "Kira_Test_Pixel8":
        print("WRONG_AVD", repr(name_raw), file=sys.stderr)
        return 2

    unlock()
    seed_prefs()
    unlock()
    adb(
        "shell",
        "am",
        "start",
        "-n",
        f"{PKG}/com.tyreest.kira_artisi_hesapla.MainActivity",
    )
    if not wait_for_app():
        print("FAIL: app not resumed", file=sys.stderr)
        return 1
    time.sleep(2.0)

    ui = dump_ui()
    descs = content_descs(ui)
    print("home descs", descs[:30])
    screenshot("renewal_scenario_a_home.png")
    joined = " ".join(descs)
    if "Yenileme geçti" in joined:
        print("FAIL: overdue on home", file=sys.stderr)
        return 1
    if "Ev" not in joined and "39.000" not in joined and "39000" not in joined:
        # Dashboard may omit property until rentals tab; still require app chrome.
        if "Özet" not in joined and "Kiralar" not in joined and "Hesapla" not in joined:
            print("FAIL: app UI not visible", joined[:500], file=sys.stderr)
            return 1
    print("SCENARIO_A_HOME_OK")

    if not tap_by_desc_substr(ui, "Kiralar"):
        adb("shell", "input", "tap", "540", "2200")
    time.sleep(1.8)
    ui = dump_ui()
    descs = content_descs(ui)
    screenshot("renewal_scenario_a_rentals.png")
    interesting = [
        d
        for d in descs
        if any(
            k in d
            for k in ("Ev", "gün", "Yenileme", "2027", "geçti", "doğrula", "39")
        )
    ]
    print("rentals", interesting)
    joined = " ".join(descs)
    if "Yenileme geçti" in joined:
        print("FAIL: overdue on rentals", file=sys.stderr)
        return 1
    if "Ev" not in joined:
        print("FAIL: seeded rental missing on Kiralarım", file=sys.stderr)
        return 1
    print("SCENARIO_A_RENTALS_OK")

    # Open detail of first Ev card if possible
    if tap_by_desc_substr(ui, "Ev"):
        time.sleep(1.5)
        ui = dump_ui()
        descs = content_descs(ui)
        screenshot("renewal_scenario_a_detail.png")
        joined = " ".join(descs)
        print(
            "detail",
            [
                d
                for d in descs
                if any(
                    k in d
                    for k in (
                        "Son",
                        "Sonraki",
                        "2026",
                        "2027",
                        "geçti",
                        "Temmuz",
                    )
                )
            ],
        )
        if "Yenileme geçti" in joined:
            print("FAIL: overdue on detail", file=sys.stderr)
            return 1
        print("SCENARIO_A_DETAIL_OK")
    return 0


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    raise SystemExit(main())
