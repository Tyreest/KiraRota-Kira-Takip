# -*- coding: utf-8 -*-
"""Güvenilir adım adım Play screenshot — paket kontrolü ile."""
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


def adb(*args: str, timeout: int = 60) -> subprocess.CompletedProcess[str]:
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


def foreground_ok() -> bool:
    r = adb("shell", "dumpsys", "activity", "activities")
    # Look near top for resumed
    head = r.stdout[:8000]
    return PKG in head and ("mResumedActivity" in head or "topResumedActivity" in head)


def ensure_app() -> None:
    if foreground_ok():
        return
    log("relaunch app")
    adb(
        "shell",
        "am",
        "start",
        "-n",
        f"{PKG}/com.tyreest.kira_artisi_hesapla.MainActivity",
    )
    time.sleep(3.0)


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
            }
        )
    return out


def blob(xml: Path) -> str:
    return "\n".join(f"{n['text']}\n{n['desc']}" for n in nodes(xml))


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))


def shot(name: str) -> None:
    ensure_app()
    dest = OUT / name
    adb("shell", "screencap", "-p", "/sdcard/play_shot.png")
    adb("pull", "/sdcard/play_shot.png", str(dest))
    log(f"SAVED {name} ({dest.stat().st_size})")


def nav(tab: str) -> None:
    ensure_app()
    tap(*NAV[tab])
    time.sleep(1.1)


def back_in_app() -> None:
    adb("shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(0.6)
    ensure_app()


def seed_and_launch() -> None:
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
        "am",
        "start",
        "-n",
        f"{PKG}/com.tyreest.kira_artisi_hesapla.MainActivity",
    )
    time.sleep(5.0)
    ensure_app()


def wait_app_text(pat: str, timeout: float = 12) -> bool:
    rx = re.compile(pat, re.I)
    end = time.time() + timeout
    while time.time() < end:
        ensure_app()
        if rx.search(blob(dump())):
            return True
        time.sleep(0.4)
    return False


def click_contains(pat: str, *, max_cy: int = 2100) -> bool:
    ensure_app()
    rx = re.compile(pat, re.I)
    cands = []
    for n in nodes(dump()):
        if n["cy"] > max_cy:
            continue
        if rx.search(n["text"]) or rx.search(n["desc"]):
            cands.append(n)
    if not cands:
        log(f"MISS {pat}")
        return False
    cands.sort(key=lambda n: n["cy"])
    n = cands[0]
    log(f"click @ {n['cx']},{n['cy']}")
    tap(n["cx"], n["cy"])
    return True


def fill_rent() -> None:
    ensure_app()
    nav("Hesapla")
    time.sleep(0.5)
    # Rent EditText is near top of form — tap fixed coords then type
    tap(540, 560)
    time.sleep(0.35)
    # Clear any junk
    for _ in range(18):
        adb("shell", "input", "keyevent", "KEYCODE_DEL")
    adb("shell", "input", "text", "38000")
    time.sleep(0.3)
    # Hide keyboard without leaving app: tap title area
    tap(200, 180)
    time.sleep(0.5)


def tap_hesapla_btn() -> None:
    ensure_app()
    xml = dump()
    cands = [
        n
        for n in nodes(xml)
        if n["cy"] < 2100
        and (
            n["text"] == "Hesapla"
            or n["desc"].split("\n")[0] == "Hesapla"
        )
    ]
    if cands:
        cands.sort(key=lambda n: n["cy"], reverse=True)
        tap(cands[0]["cx"], cands[0]["cy"])
    else:
        tap(540, 1800)
    time.sleep(2.5)


def swipe_up() -> None:
    adb("shell", "input", "swipe", "540", "1600", "540", "900", "280")
    time.sleep(0.35)


def main() -> None:
    log("=== reliable shots ===")
    seed_and_launch()
    wait_app_text(r"Hesapla|Konut|Oranlar", 15)

    # 01
    log("01 Hesapla")
    fill_rent()
    if not wait_app_text(r"38000", 3):
        fill_rent()
    shot("01_hesapla.png")

    # 02 via rental
    log("02 Sonuc")
    nav("Kiralarım")
    wait_app_text(r"Ev", 8)
    click_contains(r"^Ev\b|Ev\n", max_cy=1400) or click_contains(r"38\.?000", max_cy=1400)
    time.sleep(1.0)
    wait_app_text(r"Hesapla|PDF|ge.mi.", 8)
    # Detail Hesapla CTA
    xml = dump()
    cands = [
        n
        for n in nodes(xml)
        if "Hesapla" in (n["desc"] + n["text"]) and 400 < n["cy"] < 2000
    ]
    if cands:
        cands.sort(key=lambda n: n["cy"])
        tap(cands[0]["cx"], cands[0]["cy"])
    time.sleep(1.2)
    tap_hesapla_btn()
    wait_app_text(r"50122|50.?122|BU ORANA|Art", 12)
    for _ in range(5):
        b = blob(dump())
        if "PDF" in b and "Payla" in b:
            break
        swipe_up()
    shot("02_sonuc.png")
    back_in_app()
    back_in_app()

    # 03
    log("03 Oranlar")
    nav("Oranlar")
    wait_app_text(r"31,9|T.FE", 8)
    shot("03_oranlar.png")

    # 04
    log("04 Kiralarim")
    nav("Kiralarım")
    wait_app_text(r"Ev|38", 8)
    shot("04_kiralarim.png")

    # 05
    log("05 Detail")
    click_contains(r"38\.?000", max_cy=1400) or click_contains(r"Ev", max_cy=1400)
    time.sleep(1.0)
    wait_app_text(r"Hesapla|PDF|ge.mi.|38", 8)
    shot("05_kira_detayi.png")

    # 06
    log("06 Detail PDF")
    for _ in range(3):
        if re.search(r"PDF", blob(dump()), re.I):
            break
        swipe_up()
    shot("06_kira_detayi_pdf.png")

    # 07 Reminder — from detail if button, else settings
    log("07 Hatirlatma")
    # Try settings path without leaving
    back_in_app()
    nav("Ayarlar")
    wait_app_text(r"Ayarlar|Pro|Hat", 8)
    click_contains(r"Hat.rlatma|Yenileme", max_cy=1800)
    time.sleep(1.2)
    b = blob(dump())
    if "30" not in b:
        click_contains(r"Ev", max_cy=1600)
        time.sleep(1.0)
    wait_app_text(r"30|7", 8)
    shot("07_hatirlatma.png")

    # 08
    log("08 Ayarlar Pro")
    back_in_app()
    nav("Ayarlar")
    wait_app_text(r"Pro aktif|Ayarlar|Gizlilik", 8)
    shot("08_ayarlar_pro.png")

    # 09 PDF sheet
    log("09 PDF sheet")
    nav("Kiralarım")
    wait_app_text(r"Ev", 6)
    click_contains(r"38\.?000", max_cy=1400)
    time.sleep(1.0)
    for _ in range(4):
        if click_contains(r"PDF Raporu", max_cy=1900):
            break
        swipe_up()
    time.sleep(1.0)
    wait_app_text(r"Cihaza Kaydet", 6)
    shot("09_pdf_sheet.png")

    # 10 Share
    log("10 Share")
    click_contains(r"Payla", max_cy=2300)
    time.sleep(2.5)
    shot("10_pdf_success_or_share.png")

    log("DONE")


if __name__ == "__main__":
    main()
