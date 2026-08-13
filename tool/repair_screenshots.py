#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Repair broken/missing KiraRota QA screenshots."""
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


def run(cmd):
    print("+", " ".join(str(c) for c in cmd), flush=True)
    return subprocess.run(cmd, cwd=ROOT, capture_output=True)


def adb(*args):
    return run([str(ADB), "-s", DEVICE, *args])


def shot(name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    local = OUT / name
    # exec-out is more reliable than pull of /sdcard file
    p = run([str(ADB), "-s", DEVICE, "exec-out", "screencap", "-p"])
    if p.returncode != 0 or not p.stdout:
        print(f"FAIL screencap {name}", flush=True)
        return
    # Fix CRLF corruption on Windows pipes
    data = p.stdout.replace(b"\r\n", b"\n")
    local.write_bytes(data)
    print(f"saved {local} ({local.stat().st_size})", flush=True)


def dump() -> str:
    TMP.mkdir(parents=True, exist_ok=True)
    adb("shell", "uiautomator", "dump", "/sdcard/uidump.xml")
    local = TMP / "uidump.xml"
    adb("pull", "/sdcard/uidump.xml", str(local))
    return local.read_text(encoding="utf-8", errors="replace") if local.exists() else ""


def tap_exact(label: str, wait=1.3) -> bool:
    xml = dump()
    best = None
    for m in re.finditer(
        r'content-desc="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml
    ):
        desc = m.group(1).replace("&#10;", "\n")
        first = desc.split("\n", 1)[0].strip()
        if first != label and label not in desc:
            continue
        x1, y1, x2, y2 = map(int, m.group(2, 3, 4, 5))
        cy = (y1 + y2) // 2
        if cy >= NAV_Y_MIN and label in ("Hesapla", "Ana", "Oranlar", "Ayarlar", "Kiralarım"):
            continue
        score = 0
        if first == label:
            score += 100
        if "Button" in m.group(0) or True:
            score += 10
        if y1 < NAV_Y_MIN:
            score += 20
        cand = (score, (x1 + x2) // 2, cy, desc)
        if best is None or cand[0] > best[0]:
            best = cand
    if not best:
        print(f"WARN missing exact: {label}", flush=True)
        return False
    _, x, y, desc = best
    print(f"TAP {label!r} -> ({x},{y}) {desc[:50]!r}", flush=True)
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(wait)
    return True


def tap(x, y, wait=1.0):
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(wait)


def tab(name):
    coords = {
        "Ana": (108, 2248),
        "Kiralarım": (324, 2248),
        "Hesapla": (540, 2248),
        "Oranlar": (756, 2248),
        "Ayarlar": (972, 2248),
    }
    tap(*coords[name], 1.6)


def back(wait=1.0):
    adb("shell", "input", "keyevent", "4")
    time.sleep(wait)


def swipe(n=1):
    for _ in range(n):
        adb("shell", "input", "swipe", "540", "1500", "540", "650", "350")
        time.sleep(0.7)


def start():
    adb("shell", "am", "force-stop", PKG)
    adb("shell", "pm", "clear", PKG)
    time.sleep(1)
    adb("shell", "am", "start", "-n", ACTIVITY)
    time.sleep(9)


def main():
    import os

    phase = os.environ.get("KIRAROTA_SHOT_PHASE", "seed")
    start()

    if phase == "empty":
        shot("02_home_empty.png")
        tab("Hesapla")
        shot("07_calculate.png")
        tab("Oranlar")
        shot("10_rates.png")
        tab("Ayarlar")
        shot("11_settings.png")
        # Pro CTA button
        tap(540, 980, 1.5)  # Pro'ya Geç approximate from settings layout
        shot("12_pro_paywall.png")
        back()
        swipe(3)
        for _ in range(8):
            tap_exact("Tyreest Studio · v1.1.0", wait=0.25) or tap(540, 2050, 0.25)
        time.sleep(1.2)
        shot("15_review_access.png")
        return

    # seed phase repairs
    shot("01_home.png")
    tap_exact("Kira Ekle")
    shot("05_rental_add.png")
    back()

    tab("Kiralarım")
    shot("03_rentals.png")
    tap_exact("Beşiktaş · Daire 4") or tap_exact("Beşiktaş")
    time.sleep(1)
    shot("04_rental_detail.png")

    tap_exact("Düzenle")
    shot("06_rental_edit.png")
    back()

    # Action row buttons are small — use known relative positions from detail dump
    # Düzenle ~158, PDF ~405, Paylaş ~675, Hatırlatma ~921 at y~1376 on prior dump
    # After scroll they may move; dump again
    xml = dump()
    for label in ("Hatırlatma", "PDF"):
        m = re.search(
            rf'content-desc="{label}"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
            xml,
        )
        if not m:
            # try loose
            tap_exact(label)
            continue
        x = (int(m.group(1)) + int(m.group(3))) // 2
        y = (int(m.group(2)) + int(m.group(4))) // 2
        tap(x, y, 1.5)
        if label == "Hatırlatma":
            shot("13_reminder.png")
        else:
            shot("14_pdf_sheet.png")
        back()
        # re-open detail if needed
        if label == "Hatırlatma":
            tap_exact("Beşiktaş") or True

    # Ensure on detail then PDF if missing
    if not (OUT / "14_pdf_sheet.png").exists() or (OUT / "14_pdf_sheet.png").stat().st_size < 1000:
        tab("Kiralarım")
        tap_exact("Beşiktaş")
        xml = dump()
        m = re.search(
            r'content-desc="PDF"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml
        )
        if m:
            tap((int(m.group(1)) + int(m.group(3))) // 2, (int(m.group(2)) + int(m.group(4))) // 2, 1.8)
            shot("14_pdf_sheet.png")
            back()

    # Result: from home "Yeni dönemi hesapla" then compute
    back()
    tab("Ana")
    if tap_exact("Yeni dönemi hesapla"):
        time.sleep(1.5)
        swipe(1)
        # CTA Hesapla on form
        xml = dump()
        ms = list(
            re.finditer(
                r'content-desc="Hesapla"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
                xml,
            )
        )
        content = [m for m in ms if int(m.group(2)) < NAV_Y_MIN]
        if content:
            m = content[-1]
            tap((int(m.group(1)) + int(m.group(3))) // 2, (int(m.group(2)) + int(m.group(4))) // 2, 2.8)
        else:
            tap(540, 1880, 2.8)
        shot("08_result.png")
        swipe(2)
        # Requested rent field
        if tap_exact("Talep edilen kira") or tap_exact("Talep"):
            adb("shell", "input", "text", "55000")
            time.sleep(0.8)
            adb("shell", "input", "keyevent", "4")
            time.sleep(0.5)
        shot("09_result_requested_compare.png")

    print("REPAIR DONE", flush=True)


if __name__ == "__main__":
    main()
