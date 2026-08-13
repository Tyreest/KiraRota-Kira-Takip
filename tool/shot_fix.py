# -*- coding: utf-8 -*-
"""Kalan sorunlu screenshot'ları düzelt — yalnız Kira app, monkey relaunch."""
from __future__ import annotations

import json
import re
import shutil
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
        if not bm:
            continue
        x1, y1, x2, y2 = map(int, bm.groups())
        out.append(
            {
                "desc": (dm.group(1) if dm else "").replace("&#10;", "\n"),
                "text": (tm.group(1) if tm else "").replace("&#10;", "\n"),
                "cx": (x1 + x2) // 2,
                "cy": (y1 + y2) // 2,
            }
        )
    return out


def blob(xml: Path) -> str:
    return "\n".join(f"{n['text']}\n{n['desc']}" for n in nodes(xml))


def is_kira(xml: Path | None = None) -> bool:
    b = blob(xml or dump())
    return bool(
        re.search(
            r"Kira Art|Kira Asistan|Kiralar.m|T.FE Oran|Yenileme Hat|Pro aktif",
            b,
            re.I,
        )
    )


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))


def launch() -> None:
    adb(
        "shell",
        "monkey",
        "-p",
        PKG,
        "-c",
        "android.intent.category.LAUNCHER",
        "1",
    )
    time.sleep(3.5)


def must_kira() -> None:
    for _ in range(4):
        if is_kira():
            return
        log("not kira — relaunch")
        launch()
    raise RuntimeError("Kira app not in foreground")


def shot(name: str) -> None:
    must_kira()
    dest = OUT / name
    adb("shell", "screencap", "-p", "/sdcard/play_shot.png")
    adb("pull", "/sdcard/play_shot.png", str(dest))
    log(f"SAVED {name} ({dest.stat().st_size}) kira_ok={is_kira()}")


def nav(tab: str) -> None:
    must_kira()
    tap(*NAV[tab])
    time.sleep(1.0)
    must_kira()


def click(pat: str, *, max_cy: int = 2100, prefer_lowest: bool = False) -> bool:
    must_kira()
    rx = re.compile(pat, re.I)
    cands = [
        n
        for n in nodes(dump())
        if n["cy"] <= max_cy and (rx.search(n["text"]) or rx.search(n["desc"]))
    ]
    if not cands:
        log(f"MISS {pat}")
        return False
    cands.sort(key=lambda n: n["cy"], reverse=prefer_lowest)
    n = cands[0]
    log(f"click {n['cx']},{n['cy']}")
    tap(n["cx"], n["cy"])
    time.sleep(0.8)
    return True


def swipe_up() -> None:
    adb("shell", "input", "swipe", "540", "1550", "540", "850", "280")
    time.sleep(0.4)


def soft_back() -> None:
    adb("shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(0.7)
    if not is_kira():
        launch()
        must_kira()


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
    launch()
    must_kira()


def open_ev_detail() -> None:
    nav("Kiralarım")
    time.sleep(0.5)
    if not click(r"38", max_cy=1400):
        click(r"Ev", max_cy=1400)
    time.sleep(1.0)
    must_kira()


def main() -> None:
    log("=== fix shots ===")
    seed()

    # Keep good ones if present: 05/07/08 from previous — re-do all critical ones cleanly

    # 04 list
    log("04")
    nav("Kiralarım")
    time.sleep(0.5)
    shot("04_kiralarim.png")

    # 05 + 06 detail
    log("05/06")
    open_ev_detail()
    shot("05_kira_detayi.png")
    shot("06_kira_detayi_pdf.png")  # PDF already on this screen

    # 01 filled form via Yeni donemi hesapla
    log("01")
    click(r"Yeni d.nemi hesapla|Hesapla", max_cy=1600)
    time.sleep(1.2)
    must_kira()
    # Form should show 38000
    shot("01_hesapla.png")

    # 02 result
    log("02")
    # Tap Hesapla button (not tab)
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
    time.sleep(3.0)
    for _ in range(6):
        b = blob(dump())
        if re.search(r"PDF Raporu", b) and re.search(r"Payla|Kopyala", b):
            break
        swipe_up()
    shot("02_sonuc.png")

    # 09 PDF sheet from result
    log("09")
    if click(r"PDF Raporu", max_cy=2000):
        time.sleep(1.0)
        shot("09_pdf_sheet.png")
        # 10 share
        log("10")
        if click(r"Payla", max_cy=2300, prefer_lowest=True):
            time.sleep(2.5)
            # Share sheet may leave app — still capture
            dest = OUT / "10_pdf_success_or_share.png"
            adb("shell", "screencap", "-p", "/sdcard/play_shot.png")
            adb("pull", "/sdcard/play_shot.png", str(dest))
            log(f"SAVED 10 ({dest.stat().st_size})")
        else:
            shot("10_pdf_success_or_share.png")
    else:
        soft_back()
        soft_back()
        open_ev_detail()
        click(r"PDF Raporu", max_cy=1800)
        time.sleep(1.0)
        shot("09_pdf_sheet.png")
        click(r"Payla", max_cy=2300, prefer_lowest=True)
        time.sleep(2.5)
        dest = OUT / "10_pdf_success_or_share.png"
        adb("shell", "screencap", "-p", "/sdcard/play_shot.png")
        adb("pull", "/sdcard/play_shot.png", str(dest))
        log(f"SAVED 10 ({dest.stat().st_size})")

    # Return / 03 oranlar
    launch()
    must_kira()
    log("03")
    nav("Oranlar")
    time.sleep(0.8)
    shot("03_oranlar.png")

    # 07 reminder
    log("07")
    open_ev_detail()
    click(r"Hat.rlatmay. d.zenle|Hat.rlatma", max_cy=1800)
    time.sleep(1.2)
    shot("07_hatirlatma.png")
    soft_back()

    # 08 settings
    log("08")
    nav("Ayarlar")
    time.sleep(0.8)
    shot("08_ayarlar_pro.png")

    log("DONE")
    for p in sorted(OUT.glob("*.png")):
        log(f"  {p.name} {p.stat().st_size}")


if __name__ == "__main__":
    main()
