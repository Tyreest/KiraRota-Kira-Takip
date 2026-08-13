#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Capture KiraRota final QA screenshots on Kira_Test_Pixel8 only.

Flutter exposes labels via content-desc (not text=). Navigation uses fixed
tab coordinates on 1080x2400 Pixel 8.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "qa" / "final_screenshots"
TMP = ROOT / "docs" / "qa" / "_ui_dump"
SDK = Path(os.environ.get("LOCALAPPDATA", "")) / "Android" / "Sdk"
ADB = SDK / "platform-tools" / "adb.exe"
EXPECTED_AVD = "Kira_Test_Pixel8"
PKG = "com.tyreest.kiraartisi"
ACTIVITY = f"{PKG}/com.tyreest.kira_artisi_hesapla.MainActivity"

# Bottom NavigationBar centers on 1080x2400 (gesture nav)
TAB = {
    "Ana": (108, 2248),
    "Kiralarım": (324, 2248),
    "Hesapla": (540, 2248),
    "Oranlar": (756, 2248),
    "Ayarlar": (972, 2248),
}


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    print("+", " ".join(str(c) for c in cmd), flush=True)
    return subprocess.run(cmd, cwd=ROOT, check=check, text=True, capture_output=True, encoding="utf-8", errors="replace")


def adb(device: str, *args: str, check: bool = True) -> subprocess.CompletedProcess:
    return run([str(ADB), "-s", device, *args], check=check)


def resolve_device() -> str:
    out = run([str(ADB), "devices"]).stdout
    serials = [ln.split()[0] for ln in out.splitlines() if "\tdevice" in ln]
    for s in serials:
        raw = run([str(ADB), "-s", s, "emu", "avd", "name"], check=False).stdout
        name = next((ln.strip() for ln in raw.splitlines() if ln.strip() and ln.strip() != "OK"), "")
        print(f"device={s} avd={name!r}")
        if name == EXPECTED_AVD:
            return s
    raise SystemExit(f"AVD {EXPECTED_AVD} not found among {serials}")


def dump_xml(device: str) -> str:
    TMP.mkdir(parents=True, exist_ok=True)
    remote = "/sdcard/uidump.xml"
    adb(device, "shell", "uiautomator", "dump", remote, check=False)
    local = TMP / "uidump.xml"
    adb(device, "pull", remote, str(local), check=False)
    try:
        return local.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def find_by_desc(xml: str, needle: str) -> tuple[int, int] | None:
    """Match content-desc containing needle (Unicode-safe)."""
    for m in re.finditer(
        r'content-desc="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        xml,
    ):
        desc = m.group(1).replace("&#10;", "\n")
        if needle.lower() in desc.lower():
            x1, y1, x2, y2 = map(int, m.group(2, 3, 4, 5))
            return (x1 + x2) // 2, (y1 + y2) // 2
    # bounds before content-desc
    for m in re.finditer(
        r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"[^>]*content-desc="([^"]*)"',
        xml,
    ):
        desc = m.group(5).replace("&#10;", "\n")
        if needle.lower() in desc.lower():
            x1, y1, x2, y2 = map(int, m.group(1, 2, 3, 4))
            return (x1 + x2) // 2, (y1 + y2) // 2
    return None


def tap_desc(device: str, needle: str, wait: float = 1.3) -> bool:
    xml = dump_xml(device)
    pt = find_by_desc(xml, needle)
    if not pt:
        print(f"WARN: desc not found: {needle}", flush=True)
        return False
    adb(device, "shell", "input", "tap", str(pt[0]), str(pt[1]))
    time.sleep(wait)
    return True


def tap_xy(device: str, x: int, y: int, wait: float = 1.0) -> None:
    adb(device, "shell", "input", "tap", str(x), str(y))
    time.sleep(wait)


def tab(device: str, name: str, wait: float = 1.5) -> None:
    x, y = TAB[name]
    tap_xy(device, x, y, wait)


def press_back(device: str, wait: float = 1.0) -> None:
    adb(device, "shell", "input", "keyevent", "4")
    time.sleep(wait)


def swipe_up(device: str) -> None:
    adb(device, "shell", "input", "swipe", "540", "1500", "540", "600", "350")
    time.sleep(0.9)


def shot(device: str, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    remote = "/sdcard/kirarota_shot.png"
    adb(device, "shell", "screencap", "-p", remote)
    local = OUT / name
    adb(device, "pull", remote, str(local))
    print(f"saved {local} ({local.stat().st_size} bytes)", flush=True)


def start_app(device: str, clear: bool) -> None:
    adb(device, "shell", "am", "force-stop", PKG)
    if clear:
        adb(device, "shell", "pm", "clear", PKG)
    time.sleep(1.0)
    adb(device, "shell", "am", "start", "-n", ACTIVITY)
    time.sleep(7.0)
    # UMP / consent dismiss best-effort
    for n in ("Consent", "Accept", "I agree", "Agree", "OK", "Tamam", "Başla", "Anladım"):
        tap_desc(device, n, wait=1.0)


def set_skip_seed(device: str) -> None:
    """Create prefs so screenshot seed is skipped (empty dashboard)."""
    # Debug APK allows run-as
    script = (
        "mkdir -p /data/data/%s/shared_prefs; "
        "cat > /data/data/%s/shared_prefs/FlutterSharedPreferences.xml <<'EOF'\n"
        "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n"
        "<map>\n"
        "    <boolean name=\"flutter.screenshot_seed_skip\" value=\"true\" />\n"
        "    <boolean name=\"flutter.onboarding_done\" value=\"true\" />\n"
        "</map>\n"
        "EOF"
    ) % (PKG, PKG)
    adb(device, "shell", "run-as", PKG, "sh", "-c", script, check=False)


def main() -> None:
    device = resolve_device()
    OUT.mkdir(parents=True, exist_ok=True)

    # ---------- EMPTY (skip seed) ----------
    adb(device, "shell", "am", "force-stop", PKG)
    adb(device, "shell", "pm", "clear", PKG)
    time.sleep(0.8)
    set_skip_seed(device)
    adb(device, "shell", "am", "start", "-n", ACTIVITY)
    time.sleep(7.0)
    shot(device, "02_home_empty.png")

    tab(device, "Hesapla")
    shot(device, "07_calculate.png")

    tab(device, "Oranlar")
    shot(device, "10_rates.png")

    tab(device, "Ayarlar")
    shot(device, "11_settings.png")

    if tap_desc(device, "KiraRota Pro") or tap_desc(device, "Pro'ya Geç") or tap_desc(device, "Pro"):
        time.sleep(1.5)
        shot(device, "12_pro_paywall.png")
        press_back(device)
    else:
        # open via common settings card area
        tap_xy(device, 540, 420)
        time.sleep(1.5)
        shot(device, "12_pro_paywall.png")
        press_back(device)

    # Review access: 7 taps on version row (bottom of settings)
    swipe_up(device)
    swipe_up(device)
    for _ in range(8):
        if not (tap_desc(device, "Sürüm") or tap_desc(device, "1.1.0") or tap_desc(device, "Hakkında")):
            tap_xy(device, 540, 2000, wait=0.25)
        else:
            time.sleep(0.25)
    time.sleep(1.2)
    shot(device, "15_review_access.png")
    press_back(device)

    # ---------- SEEDED ----------
    start_app(device, clear=True)  # clears skip flag → seed applies
    time.sleep(1.5)
    shot(device, "01_home.png")

    tab(device, "Kiralarım")
    shot(device, "03_rentals.png")

    if tap_desc(device, "Beşiktaş") or tap_desc(device, "Daire 4") or tap_desc(device, "38.000"):
        time.sleep(1.5)
        shot(device, "04_rental_detail.png")

        swipe_up(device)
        if tap_desc(device, "Düzenle"):
            time.sleep(1.2)
            shot(device, "06_rental_edit.png")
            press_back(device)

        if tap_desc(device, "Hatırlat"):
            time.sleep(1.2)
            shot(device, "13_reminder.png")
            press_back(device)

        if tap_desc(device, "PDF"):
            time.sleep(1.5)
            shot(device, "14_pdf_sheet.png")
            press_back(device)
        else:
            # detail may need scroll for PDF
            swipe_up(device)
            if tap_desc(device, "PDF"):
                time.sleep(1.5)
                shot(device, "14_pdf_sheet.png")
                press_back(device)

        press_back(device)
    else:
        print("WARN: rental card not opened", flush=True)

    tab(device, "Ana")
    if tap_desc(device, "Kira Ekle"):
        time.sleep(1.2)
        shot(device, "05_rental_add.png")
        press_back(device)

    # Result + requested compare via manual calc
    tab(device, "Hesapla")
    # Prefill hard: tap rent field by approx coords then type
    tap_xy(device, 540, 520, wait=0.4)
    adb(device, "shell", "input", "text", "38000")
    time.sleep(0.4)
    # dismiss keyboard
    adb(device, "shell", "input", "keyevent", "4")
    time.sleep(0.4)
    swipe_up(device)
    if tap_desc(device, "Hesapla") or True:
        # CTA near bottom above nav
        tap_xy(device, 540, 1980, wait=0.2)
        tap_desc(device, "Hesapla", wait=2.5)
    time.sleep(2.0)
    shot(device, "08_result.png")
    swipe_up(device)
    swipe_up(device)
    if tap_desc(device, "Talep") or tap_desc(device, "Karşılaştır"):
        adb(device, "shell", "input", "text", "55000")
        time.sleep(1.0)
        adb(device, "shell", "input", "keyevent", "4")
        time.sleep(0.5)
    shot(device, "09_result_requested_compare.png")

    print("DONE screenshot set", flush=True)
    for p in sorted(OUT.glob("*.png")):
        if p.name.startswith("_"):
            continue
        print(f"  {p.name}: {p.stat().st_size}", flush=True)


if __name__ == "__main__":
    main()
