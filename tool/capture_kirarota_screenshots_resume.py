#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Resume / finish remaining KiraRota screenshots with resilient adb taps."""
from __future__ import annotations

import re
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "qa" / "final_screenshots"
TMP = ROOT / "docs" / "qa" / "_ui_dump"
SDK = Path(__import__("os").environ.get("LOCALAPPDATA", "")) / "Android" / "Sdk"
ADB = SDK / "platform-tools" / "adb.exe"
PKG = "com.tyreest.kiraartisi"
ACTIVITY = f"{PKG}/com.tyreest.kira_artisi_hesapla.MainActivity"
DEVICE = "emulator-5554"

TAB = {
    "Özet": (108, 2248),
    "Kiralarım": (324, 2248),
    "Hesapla": (540, 2248),
    "Oranlar": (756, 2248),
    "Ayarlar": (972, 2248),
}


def run(cmd, check=False):
    print("+", " ".join(str(c) for c in cmd), flush=True)
    return subprocess.run(
        cmd,
        cwd=ROOT,
        check=check,
        text=True,
        capture_output=True,
        encoding="utf-8",
        errors="replace",
    )


def adb(*args, check=False):
    return run([str(ADB), "-s", DEVICE, *args], check=check)


def dump():
    TMP.mkdir(parents=True, exist_ok=True)
    adb("shell", "uiautomator", "dump", "/sdcard/uidump.xml")
    local = TMP / "uidump.xml"
    adb("pull", "/sdcard/uidump.xml", str(local))
    return local.read_text(encoding="utf-8", errors="replace") if local.exists() else ""


def find(xml, needle):
    for m in re.finditer(
        r'content-desc="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml
    ):
        if needle.lower() in m.group(1).lower().replace("&#10;", "\n"):
            a, b, c, d = map(int, m.group(2, 3, 4, 5))
            return (a + c) // 2, (b + d) // 2
    for m in re.finditer(
        r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"[^>]*content-desc="([^"]*)"', xml
    ):
        if needle.lower() in m.group(5).lower().replace("&#10;", "\n"):
            a, b, c, d = map(int, m.group(1, 2, 3, 4))
            return (a + c) // 2, (b + d) // 2
    return None


def tap_desc(needle, wait=1.3):
    pt = find(dump(), needle)
    if not pt:
        print(f"WARN missing: {needle}", flush=True)
        return False
    adb("shell", "input", "tap", str(pt[0]), str(pt[1]))
    time.sleep(wait)
    return True


def tap(x, y, wait=1.0):
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(wait)


def tab(name, wait=1.5):
    x, y = TAB[name]
    tap(x, y, wait)


def back(wait=1.0):
    adb("shell", "input", "keyevent", "4")
    time.sleep(wait)


def swipe():
    adb("shell", "input", "swipe", "540", "1500", "540", "600", "350")
    time.sleep(0.8)


def shot(name):
    OUT.mkdir(parents=True, exist_ok=True)
    adb("shell", "screencap", "-p", "/sdcard/kirarota_shot.png")
    local = OUT / name
    adb("pull", "/sdcard/kirarota_shot.png", str(local))
    print(f"saved {local} ({local.stat().st_size})", flush=True)


def write_empty_prefs():
    xml = """<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="flutter.screenshot_seed_skip" value="true" />
    <boolean name="flutter.onboarding_done" value="true" />
</map>
"""
    local = TMP / "FlutterSharedPreferences.xml"
    TMP.mkdir(parents=True, exist_ok=True)
    local.write_text(xml, encoding="utf-8")
    adb("push", str(local), "/data/local/tmp/FlutterSharedPreferences.xml")
    adb(
        "shell",
        "run-as",
        PKG,
        "cp",
        "/data/local/tmp/FlutterSharedPreferences.xml",
        "shared_prefs/FlutterSharedPreferences.xml",
    )


def main():
    # Ensure seeded app is up for remaining detail flows
    adb("shell", "am", "force-stop", PKG)
    adb("shell", "pm", "clear", PKG)
    time.sleep(0.5)
    adb("shell", "am", "start", "-n", ACTIVITY)
    time.sleep(7)

    # Home seeded
    shot("01_home.png")

    # Add rental form
    if tap_desc("Kira Ekle"):
        time.sleep(1)
        shot("05_rental_add.png")
        back()

    # Detail actions
    tab("Kiralarım")
    shot("03_rentals.png")
    if tap_desc("Beşiktaş") or tap_desc("Daire"):
        time.sleep(1.2)
        shot("04_rental_detail.png")
        if tap_desc("Düzenle"):
            time.sleep(1)
            shot("06_rental_edit.png")
            back()
        if tap_desc("Hatırlatma"):
            time.sleep(1.2)
            shot("13_reminder.png")
            back()
        if tap_desc("PDF"):
            time.sleep(1.5)
            shot("14_pdf_sheet.png")
            # may open paywall for free — still capture
            back()
        back()

    # Calculate + result
    tab("Hesapla")
    shot("07_calculate.png")
    # Focus first text field roughly and type
    tap(540, 560, 0.4)
    adb("shell", "input", "text", "38000")
    time.sleep(0.3)
    adb("shell", "input", "keyevent", "4")
    swipe()
    tap_desc("Hesapla", wait=2.5) or tap(540, 1950, 2.5)
    time.sleep(1.5)
    shot("08_result.png")
    swipe()
    swipe()
    if tap_desc("Talep") or tap_desc("Karşılaştır"):
        adb("shell", "input", "text", "55000")
        time.sleep(0.8)
        adb("shell", "input", "keyevent", "4")
        time.sleep(0.6)
    shot("09_result_requested_compare.png")
    back()

    # Settings / paywall / review
    tab("Ayarlar")
    shot("11_settings.png")
    if tap_desc("Pro'ya Geç") or tap_desc("Proya Gec") or tap_desc("KiraRota Pro"):
        time.sleep(1.5)
        shot("12_pro_paywall.png")
        back()

    swipe()
    swipe()
    # Version row near bottom
    for _ in range(8):
        if not tap_desc("Tyreest"):
            tap(540, 2050, 0.2)
        time.sleep(0.2)
    time.sleep(1.2)
    shot("15_review_access.png")
    back()

    # EMPTY home with skip prefs
    adb("shell", "am", "force-stop", PKG)
    adb("shell", "pm", "clear", PKG)
    time.sleep(0.5)
    write_empty_prefs()
    adb("shell", "am", "start", "-n", ACTIVITY)
    time.sleep(7)
    shot("02_home_empty.png")

    print("RESUME DONE", flush=True)


if __name__ == "__main__":
    main()
