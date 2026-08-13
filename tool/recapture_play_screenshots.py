# -*- coding: utf-8 -*-
"""Tekrar/manuel düzeltme yakalamaları — UMP sonrası temiz kareler."""
from __future__ import annotations

import json
import re
import subprocess
import time
from pathlib import Path

ADB = str(Path.home() / "AppData/Local/Android/Sdk/platform-tools/adb.exe")
EMU = "emulator-5554"
PKG = "com.tyreest.kiraartisi"
ROOT = Path(r"C:\Users\yigit\Desktop\Projeler\kira-artisi-hesapla")
OUT = ROOT / "store_assets" / "raw_screenshots"
TMP = ROOT / "store_assets" / "_tmp_ui"
OUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)

NAV = {
    "Hesapla": (135, 2242),
    "Oranlar": (405, 2242),
    "Kiralarım": (675, 2242),
    "Ayarlar": (945, 2242),
}

DEMO_RENTALS = [
    {
        "id": "demo-ev-1",
        "role": "tenant",
        "displayName": "Ev",
        "currentRent": 38000,
        "contractStartDate": "2024-08-01T00:00:00.000",
        "increaseDate": "2026-08-15T00:00:00.000",
        "contractIncreaseRate": None,
        "createdAt": "2026-08-01T10:00:00.000",
        "updatedAt": "2026-08-08T10:00:00.000",
        "reminder": {
            "enabled": True,
            "notify30": True,
            "notify7": True,
            "notify0": True,
        },
        "history": [
            {
                "id": "snap-demo-1",
                "calculatedAt": "2026-08-08T09:30:00.000",
                "oldRent": 38000,
                "calculatedRent": 50122,
                "tufeRatePercent": 31.9,
                "applicableRatePercent": 31.9,
                "tufeReferenceMonth": "2026-08",
                "increaseDate": "2026-08-15T00:00:00.000",
                "contractRatePercent": None,
                "isFiveYearsOrMore": False,
            }
        ],
    }
]


def adb(*args: str, timeout: int = 90) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [ADB, "-s", EMU, *args],
        check=False,
        text=True,
        capture_output=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )


def log(msg: str) -> None:
    print(msg.encode("ascii", "replace").decode("ascii"), flush=True)


def dump() -> Path:
    adb("shell", "uiautomator", "dump", "/sdcard/ui_shot.xml")
    p = TMP / "cur.xml"
    adb("pull", "/sdcard/ui_shot.xml", str(p))
    return p


def nodes(xml: Path) -> list[dict]:
    raw = xml.read_text(encoding="utf-8", errors="replace")
    out = []
    for m in re.finditer(r"<node [^>]+/?>", raw):
        s = m.group(0)
        dm = re.search(r'content-desc="([^"]*)"', s)
        tm = re.search(r'text="([^"]*)"', s)
        bm = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', s)
        cm = re.search(r'class="([^"]*)"', s)
        if not bm:
            continue
        x1, y1, x2, y2 = map(int, bm.groups())
        out.append(
            {
                "desc": (dm.group(1) if dm else "").replace("&#10;", "\n"),
                "text": (tm.group(1) if tm else "").replace("&#10;", "\n"),
                "cls": cm.group(1) if cm else "",
                "cx": (x1 + x2) // 2,
                "cy": (y1 + y2) // 2,
                "clickable": 'clickable="true"' in s,
            }
        )
    return out


def blob(xml: Path) -> str:
    return "\n".join(f"{n['text']}\n{n['desc']}" for n in nodes(xml))


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))


def shot(name: str) -> None:
    dest = OUT / name
    adb("shell", "screencap", "-p", "/sdcard/play_shot.png")
    adb("pull", "/sdcard/play_shot.png", str(dest))
    log(f"SAVED {name} ({dest.stat().st_size})")


def nav(tab: str) -> None:
    tap(*NAV[tab])
    time.sleep(1.0)


def click_text_or_desc(pattern: str, *, max_cy: int | None = None) -> bool:
    rx = re.compile(pattern, re.I)
    xml = dump()
    cands = []
    for n in nodes(xml):
        if rx.search(n["text"]) or rx.search(n["desc"]):
            if max_cy is not None and n["cy"] > max_cy:
                continue
            cands.append(n)
    if not cands:
        log(f"MISS {pattern}")
        return False
    cands.sort(key=lambda n: n["cy"], reverse=True)
    n = cands[0]
    log(f"click {(n['text'] or n['desc'])[:50]} @ {n['cx']},{n['cy']}")
    tap(n["cx"], n["cy"])
    return True


def wait_until(pattern: str, timeout: float = 20.0) -> bool:
    rx = re.compile(pattern, re.I)
    end = time.time() + timeout
    while time.time() < end:
        if rx.search(blob(dump())):
            return True
        time.sleep(0.4)
    return False


def dismiss_ump_hard() -> None:
    for i in range(8):
        b = blob(dump())
        if re.search(r"Publisher Test Ads|Welcome to Publisher|\bConsent\b", b, re.I):
            log(f"UMP try {i}")
            xml = dump()
            hit = False
            for n in nodes(xml):
                if n["text"].strip() in ("Consent", "Do not consent"):
                    tap(n["cx"], n["cy"])
                    hit = True
                    break
            if not hit:
                tap(540, 1680)
            time.sleep(1.2)
            continue
        if re.search(r"Konut|Oranlar|Kiralar|Ayarlar|Hesapla", b):
            log("home ready")
            return
        time.sleep(0.4)
    log("UMP warn: continue anyway")


def seed() -> None:
    rentals_json = json.dumps(DEMO_RENTALS, ensure_ascii=False, separators=(",", ":"))
    rentals_xml = (
        rentals_json.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    )
    xml = f"""<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="flutter.onboarding_done" value="true" />
    <boolean name="flutter.is_pro_lifetime" value="true" />
    <boolean name="flutter.review_access_enabled" value="true" />
    <string name="flutter.rentals_v1">{rentals_xml}</string>
</map>
"""
    local = TMP / "FlutterSharedPreferences.xml"
    local.write_text(xml, encoding="utf-8")
    adb("shell", "am", "force-stop", PKG)
    adb("shell", "pm", "clear", PKG)
    time.sleep(1.0)
    adb("shell", "run-as", PKG, "mkdir", "-p", "shared_prefs")
    adb("push", str(local), "/data/local/tmp/FlutterSharedPreferences.xml")
    adb(
        "shell",
        f"run-as {PKG} cp /data/local/tmp/FlutterSharedPreferences.xml "
        f"shared_prefs/FlutterSharedPreferences.xml",
    )
    adb("shell", "settings", "put", "system", "show_touches", "0")
    adb("shell", "settings", "put", "system", "pointer_location", "0")
    adb(
        "shell",
        "monkey",
        "-p",
        PKG,
        "-c",
        "android.intent.category.LAUNCHER",
        "1",
    )
    time.sleep(4.5)


def fill_38000() -> None:
    # Focus rent field via semantics "Mevcut aylık kira"
    click_text_or_desc(r"Mevcut", max_cy=1200)
    time.sleep(0.4)
    # Select-all + delete
    adb("shell", "input", "keyevent", "KEYCODE_MOVE_END")
    for _ in range(16):
        adb("shell", "input", "keyevent", "KEYCODE_DEL")
    adb("shell", "input", "text", "38000")
    time.sleep(0.3)
    adb("shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(0.5)


def tap_calc() -> None:
    xml = dump()
    cands = [
        n
        for n in nodes(xml)
        if (n["desc"].split("\n")[0] == "Hesapla" or n["text"] == "Hesapla")
        and n["cy"] < 2100
    ]
    if cands:
        cands.sort(key=lambda n: n["cy"], reverse=True)
        tap(cands[0]["cx"], cands[0]["cy"])
    else:
        tap(540, 1800)


def swipe_up(dy: int = 700) -> None:
    adb("shell", "input", "swipe", "540", "1650", "540", str(1650 - dy), "280")


def back(n: int = 1) -> None:
    for _ in range(n):
        adb("shell", "input", "keyevent", "KEYCODE_BACK")
        time.sleep(0.5)


def main() -> None:
    log("=== recapture ===")
    seed()
    dismiss_ump_hard()
    # Extra settle after consent / ads init
    time.sleep(2.0)
    dismiss_ump_hard()

    # ---- 01 Hesapla filled ----
    log("01")
    nav("Hesapla")
    time.sleep(0.5)
    dismiss_ump_hard()
    fill_38000()
    # Verify 38000 visible
    if not wait_until(r"38000", 4):
        fill_38000()
    shot("01_hesapla.png")

    # ---- 02 Sonuc via Ev ----
    log("02")
    nav("Kiralarım")
    wait_until(r"\bEv\b", 10)
    time.sleep(0.5)
    click_text_or_desc(r"\bEv\b", max_cy=1600)
    time.sleep(1.0)
    # Detail Hesapla
    xml = dump()
    cands = [
        n
        for n in nodes(xml)
        if "Hesapla" in (n["desc"] + n["text"]) and n["cy"] < 2000
    ]
    if cands:
        cands.sort(key=lambda n: n["cy"])
        tap(cands[0]["cx"], cands[0]["cy"])
    time.sleep(1.2)
    # Should be hydrated with 38000
    tap_calc()
    time.sleep(2.8)
    wait_until(r"50122|50.?122|BU ORANA|Art", 12)
    for _ in range(5):
        b = blob(dump())
        if re.search(r"PDF Raporu", b) and re.search(r"Payla", b):
            break
        swipe_up(600)
        time.sleep(0.3)
    # Make sure Yeni kirayi kaydet visible if possible
    shot("02_sonuc.png")
    back(2)

    # ---- 03 Oranlar (already ok, refresh) ----
    log("03")
    nav("Oranlar")
    wait_until(r"31,9|T.FE", 8)
    shot("03_oranlar.png")

    # ---- 04 Kiralarim ----
    log("04")
    nav("Kiralarım")
    wait_until(r"38.?000|Ev", 8)
    shot("04_kiralarim.png")

    # ---- 05 / 06 Detail ----
    log("05/06")
    click_text_or_desc(r"\bEv\b", max_cy=1600)
    time.sleep(1.0)
    wait_until(r"Ev|ge.mi.|Hesapla", 8)
    shot("05_kira_detayi.png")
    for _ in range(3):
        if re.search(r"PDF", blob(dump()), re.I):
            break
        swipe_up(500)
        time.sleep(0.25)
    shot("06_kira_detayi_pdf.png")

    # ---- 07 Reminder ----
    log("07")
    back(1)
    nav("Ayarlar")
    click_text_or_desc(r"Yenileme Hat")
    time.sleep(1.2)
    b = blob(dump())
    if "30" not in b and re.search(r"Ev", b):
        click_text_or_desc(r"\bEv\b")
        time.sleep(1.0)
    wait_until(r"30|7 g", 8)
    shot("07_hatirlatma.png")

    # ---- 08 Settings Pro ----
    log("08")
    back(1)
    nav("Ayarlar")
    wait_until(r"Pro aktif|Ayarlar", 8)
    shot("08_ayarlar_pro.png")

    # ---- 09 PDF sheet ----
    log("09")
    nav("Kiralarım")
    time.sleep(0.7)
    click_text_or_desc(r"\bEv\b", max_cy=1600)
    time.sleep(0.8)
    for _ in range(3):
        if click_text_or_desc(r"PDF Raporu", max_cy=1800):
            break
        swipe_up(450)
        time.sleep(0.3)
    time.sleep(1.0)
    wait_until(r"Cihaza Kaydet", 6)
    shot("09_pdf_sheet.png")

    # ---- 10 Share sheet ----
    log("10")
    click_text_or_desc(r"^Payla")
    time.sleep(2.5)
    shot("10_pdf_success_or_share.png")

    log("DONE")


if __name__ == "__main__":
    main()
