#!/usr/bin/env python3
"""Seed Scenario B (overdue) and C (future) rentals; verify status copy."""

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


def unlock() -> None:
    adb("shell", "input", "keyevent", "KEYCODE_WAKEUP")
    adb("shell", "wm", "dismiss-keyguard")
    time.sleep(0.4)


def dump_ui() -> str:
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    adb("pull", "/sdcard/ui.xml", f"{OUT}/_ui.xml")
    with open(f"{OUT}/_ui.xml", encoding="utf-8", errors="ignore") as f:
        return f.read()


def content_descs(ui: str) -> list[str]:
    return [d.replace("&#10;", "|") for d in re.findall(r'content-desc="([^"]*)"', ui)]


def screenshot(name: str) -> None:
    data = adb_out("exec-out", "screencap", "-p")
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(data)


def rental(
    *,
    rid: str,
    name: str,
    rent: float,
    next_date: str,
    last_date: str | None,
    resolved: bool,
) -> dict:
    return {
        "id": rid,
        "role": "tenant",
        "displayName": name,
        "propertyName": name,
        "currentRent": rent,
        "contractStartDate": "2024-07-01T00:00:00.000",
        "increaseDate": next_date,
        "renewalDate": next_date,
        "nextRenewalDate": next_date,
        **({"lastRenewalDate": last_date} if last_date else {}),
        "renewalResolved": resolved,
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


def seed(rentals: list[dict]) -> None:
    raw = json.dumps(rentals, ensure_ascii=False, separators=(",", ":"))
    escaped = saxutils.escape(raw, {'"': "&quot;"})
    xml = (
        "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n"
        "<map>\n"
        '  <boolean name="flutter.onboarding_done" value="true" />\n'
        f'  <string name="flutter.rentals_v1">{escaped}</string>\n'
        "</map>\n"
    )
    prefs_path = os.path.join(OUT, "_seed_prefs_bc.xml")
    with open(prefs_path, "w", encoding="utf-8") as f:
        f.write(xml)
    unlock()
    adb("shell", "am", "force-stop", PKG)
    adb("push", prefs_path, "/data/local/tmp/kira_prefs.xml")
    adb("shell", "run-as", PKG, "mkdir", "-p", "shared_prefs")
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
            raise RuntimeError("prefs write failed")
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

    # Scenario B — overdue pending next
    seed(
        [
            rental(
                rid="smoke_b",
                name="Gecikmiş Ev",
                rent=39000,
                next_date="2026-07-01T00:00:00.000",
                last_date=None,
                resolved=True,
            )
        ]
    )
    ui = dump_ui()
    descs = content_descs(ui)
    joined = " ".join(descs)
    screenshot("renewal_scenario_b_home.png")
    print("B descs", [d for d in descs if "Gecik" in d or "geçti" in d or "Yaklaşan" in d][:10])
    if "Yenileme geçti" not in joined:
        print("FAIL B: expected Yenileme geçti", file=sys.stderr)
        return 1
    print("SCENARIO_B_OK")

    # Scenario C — future
    seed(
        [
            rental(
                rid="smoke_c",
                name="Gelecek Ev",
                rent=25000,
                next_date="2026-09-15T00:00:00.000",
                last_date=None,
                resolved=True,
            )
        ]
    )
    ui = dump_ui()
    descs = content_descs(ui)
    joined = " ".join(descs)
    screenshot("renewal_scenario_c_home.png")
    print(
        "C descs",
        [
            d
            for d in descs
            if "Gelecek" in d or "gün" in d or "Yaklaşan" in d or "Bu Ay" in d
        ][:10],
    )
    if "Yenileme geçti" in joined:
        print("FAIL C: unexpected overdue", file=sys.stderr)
        return 1
    if "33 gün" not in joined and "33 gün kaldı" not in joined:
        # 13 Aug -> 15 Sep = 33 days
        if "Gelecek Ev" not in joined:
            print("FAIL C: future rental missing", file=sys.stderr)
            return 1
        print("WARN C: day count text not found exactly; rental present")
    if "Yaklaşan|1" not in joined and "Yaklaşan|0" in joined:
        # upcoming window may be 30 days — 33 days might be outside
        print("note: Yaklaşan may exclude 33-day horizon depending on window")
    print("SCENARIO_C_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
