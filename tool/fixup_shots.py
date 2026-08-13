#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import re, subprocess, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/qa/final_screenshots"
ADB = Path.home() / "AppData/Local/Android/Sdk/platform-tools/adb.exe"
D = "emulator-5554"
PKG = "com.tyreest.kiraartisi"
ACT = f"{PKG}/com.tyreest.kira_artisi_hesapla.MainActivity"


def adb(*a):
    print("+", *a, flush=True)
    return subprocess.run([str(ADB), "-s", D, *a], capture_output=True)


def shot(name):
    adb("shell", "screencap", "-p", "/sdcard/k.png")
    dest = OUT / name
    adb("pull", "/sdcard/k.png", str(dest))
    n = dest.stat().st_size
    assert n > 1000, name
    print("OK", name, n, flush=True)


def tap(x, y, w=1.0):
    adb("shell", "input", "tap", str(int(x)), str(int(y)))
    time.sleep(w)


def dump():
    adb("shell", "uiautomator", "dump", "/sdcard/u.xml")
    p = adb("shell", "cat", "/sdcard/u.xml")
    return p.stdout.decode("utf-8", "replace")


def find_desc(xml, needle, max_y=2100):
    best = None
    for m in re.finditer(
        r'content-desc="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml
    ):
        if needle.lower() not in m.group(1).lower():
            continue
        x1, y1, x2, y2 = map(int, m.groups()[1:])
        if y1 >= max_y:
            continue
        best = ((x1 + x2) // 2, (y1 + y2) // 2, m.group(1))
    return best


def start_clear():
    adb("shell", "am", "force-stop", PKG)
    adb("shell", "pm", "clear", PKG)
    time.sleep(0.8)
    adb("shell", "am", "start", "-n", ACT)
    time.sleep(9)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    phase = __import__("os").environ.get("PHASE", "seed")
    start_clear()
    if phase == "seed":
        tap(324, 2248, 1.4)
        tap(540, 944, 1.3)
        shot("04_rental_detail.png")
        tap(921, 1376, 1.6)
        shot("13_reminder.png")
        adb("shell", "input", "keyevent", "4")
        time.sleep(1.2)
        tap(413, 1376, 1.8)
        shot("14_pdf_sheet.png")
        adb("shell", "input", "keyevent", "4")
        time.sleep(0.8)
        adb("shell", "input", "keyevent", "4")
        time.sleep(0.8)
        tap(108, 2248, 1.4)
        pt = find_desc(dump(), "Yeni")
        if pt:
            tap(pt[0], pt[1], 1.8)
        else:
            tap(540, 1132, 1.8)
        adb("shell", "input", "swipe", "540", "1500", "540", "700", "300")
        time.sleep(0.8)
        xml = dump()
        hp = find_desc(xml, "Hesapla")
        if hp:
            tap(hp[0], hp[1], 3.0)
        else:
            tap(540, 1793, 3.0)
        shot("08_result.png")
        xml = dump()
        tp = find_desc(xml, "Talep") or find_desc(xml, "55000")
        if tp:
            tap(tp[0], tp[1], 0.5)
        else:
            tap(540, 1020, 0.5)
        adb("shell", "input", "text", "55000")
        time.sleep(1.2)
        adb("shell", "input", "keyevent", "4")
        time.sleep(0.6)
        shot("09_result_requested_compare.png")
    else:
        tap(972, 2248, 1.5)
        for _ in range(2):
            adb("shell", "input", "swipe", "540", "1700", "540", "500", "300")
            time.sleep(0.5)
        xml = dump()
        vp = find_desc(xml, "Tyreest", max_y=2400)
        if not vp:
            vp = (540, 2043, "fallback")
        print("version", vp, flush=True)
        for _ in range(8):
            adb("shell", "input", "tap", str(vp[0]), str(vp[1]))
            time.sleep(0.05)
        time.sleep(1.5)
        shot("15_review_access.png")
    print("DONE", flush=True)


if __name__ == "__main__":
    main()
