#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Final resilient screenshot capture for KiraRota on Kira_Test_Pixel8."""
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
DEVICE = "emulator-5554"
PKG = "com.tyreest.kiraartisi"
ACTIVITY = f"{PKG}/com.tyreest.kira_artisi_hesapla.MainActivity"
NAV_Y_MIN = 2100

TAB = {
    "Özet": (108, 2248),
    "Kiralarım": (324, 2248),
    "Hesapla": (540, 2248),
    "Oranlar": (756, 2248),
    "Ayarlar": (972, 2248),
}


def run(cmd):
    print("+", " ".join(str(c) for c in cmd), flush=True)
    return subprocess.run(
        cmd,
        cwd=ROOT,
        text=True,
        capture_output=True,
        encoding="utf-8",
        errors="replace",
    )


def adb(*args):
    return run([str(ADB), "-s", DEVICE, *args])


def dump():
    TMP.mkdir(parents=True, exist_ok=True)
    adb("shell", "uiautomator", "dump", "/sdcard/uidump.xml")
    local = TMP / "uidump.xml"
    adb("pull", "/sdcard/uidump.xml", str(local))
    return local.read_text(encoding="utf-8", errors="replace") if local.exists() else ""


def candidates(xml, needle):
    out = []
    for m in re.finditer(
        r'content-desc="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml
    ):
        desc = m.group(1).replace("&#10;", "\n")
        if needle.lower() in desc.lower():
            x1, y1, x2, y2 = map(int, m.group(2, 3, 4, 5))
            out.append(((x1 + x2) // 2, (y1 + y2) // 2, y1, desc))
    return out


def tap_desc(needle, prefer_content=True, wait=1.3):
    cands = candidates(dump(), needle)
    if not cands:
        print(f"WARN missing: {needle}", flush=True)
        return False
    if prefer_content:
        content = [c for c in cands if c[2] < NAV_Y_MIN]
        if content:
            cands = content
    # Prefer lower on screen among content (often CTAs), else first
    cands.sort(key=lambda c: c[2], reverse=True)
    x, y, _, desc = cands[0]
    print(f"TAP {needle!r} -> ({x},{y}) desc={desc[:60]!r}", flush=True)
    adb("shell", "input", "tap", str(x), str(y))
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


def swipe(times=1):
    for _ in range(times):
        adb("shell", "input", "swipe", "540", "1500", "540", "650", "350")
        time.sleep(0.7)


def shot(name):
    OUT.mkdir(parents=True, exist_ok=True)
    adb("shell", "screencap", "-p", "/sdcard/kirarota_shot.png")
    local = OUT / name
    adb("pull", "/sdcard/kirarota_shot.png", str(local))
    print(f"saved {local} ({local.stat().st_size})", flush=True)


def start_fresh():
    adb("shell", "am", "force-stop", PKG)
    adb("shell", "pm", "clear", PKG)
    time.sleep(0.8)
    adb("shell", "am", "start", "-n", ACTIVITY)
    time.sleep(7.5)


def ensure_avd():
    raw = adb("emu", "avd", "name").stdout
    name = next((ln.strip() for ln in raw.splitlines() if ln.strip() and ln.strip() != "OK"), "")
    if name != "Kira_Test_Pixel8":
        raise SystemExit(f"Wrong AVD: {name!r}")
    print(f"AVD OK: {name}", flush=True)


def main():
    ensure_avd()
    OUT.mkdir(parents=True, exist_ok=True)

    # Caller must install matching APK:
    # 1) empty mode first if capturing 02
    # This script assumes CURRENT install mode via env KIRAROTA_SHOT_PHASE=empty|seed|all
    import os

    phase = os.environ.get("KIRAROTA_SHOT_PHASE", "all")

    if phase in ("empty", "all"):
        start_fresh()
        shot("02_home_empty.png")
        tab("Hesapla")
        shot("07_calculate.png")
        tab("Oranlar")
        shot("10_rates.png")
        tab("Ayarlar")
        shot("11_settings.png")
        # Paywall via Pro'ya Geç (ASCII-safe partial)
        if tap_desc("Pro") or tap_desc("Geç"):
            time.sleep(1.2)
            shot("12_pro_paywall.png")
            back()
        # Review access sheet: scroll + tap version row
        swipe(2)
        for _ in range(8):
            if not tap_desc("Studio", prefer_content=True, wait=0.25):
                tap(540, 2060, 0.2)
        time.sleep(1.0)
        shot("15_review_access.png")
        back()

    if phase in ("seed", "all"):
        start_fresh()
        shot("01_home.png")

        if tap_desc("Kira Ekle"):
            time.sleep(1.0)
            shot("05_rental_add.png")
            back()

        tab("Kiralarım")
        shot("03_rentals.png")
        if tap_desc("Beşiktaş") or tap_desc("Daire"):
            time.sleep(1.2)
            shot("04_rental_detail.png")
            if tap_desc("Düzenle"):
                time.sleep(1.0)
                shot("06_rental_edit.png")
                back()
            if tap_desc("Hatırlatma"):
                time.sleep(1.3)
                shot("13_reminder.png")
                back()
            if tap_desc("PDF"):
                time.sleep(1.5)
                shot("14_pdf_sheet.png")
                back()
            back()

        # Result flow
        tab("Hesapla")
        tap(540, 560, 0.4)
        adb("shell", "input", "text", "38000")
        time.sleep(0.3)
        adb("shell", "input", "keyevent", "4")
        time.sleep(0.3)
        swipe(1)
        # Prefer non-nav Hesapla CTA
        if not tap_desc("Hesapla", prefer_content=True, wait=2.8):
            tap(540, 1880, 2.8)
        shot("08_result.png")
        swipe(2)
        if tap_desc("Talep") or tap_desc("karşılaştır") or tap_desc("edilen"):
            adb("shell", "input", "text", "55000")
            time.sleep(0.9)
            adb("shell", "input", "keyevent", "4")
            time.sleep(0.5)
        shot("09_result_requested_compare.png")

    print("FINAL CAPTURE DONE", flush=True)
    for p in sorted(OUT.glob("*.png")):
        if not p.name.startswith("_"):
            print(f"  {p.name}: {p.stat().st_size}", flush=True)


if __name__ == "__main__":
    main()
