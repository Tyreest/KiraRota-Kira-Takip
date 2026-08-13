# -*- coding: utf-8 -*-
"""Eksik screenshot'lar: 01,02,05,06,09,10 — soft waits."""
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

NAV = {"Hesapla": (135, 2242), "Oranlar": (405, 2242), "Kiralarım": (675, 2242), "Ayarlar": (945, 2242)}

DEMO = [{
    "id": "demo-ev-1", "role": "tenant", "displayName": "Ev", "currentRent": 38000,
    "contractStartDate": "2024-08-01T00:00:00.000", "increaseDate": "2026-08-15T00:00:00.000",
    "contractIncreaseRate": None, "createdAt": "2026-08-01T10:00:00.000",
    "updatedAt": "2026-08-08T10:00:00.000",
    "reminder": {"enabled": True, "notify30": True, "notify7": True, "notify0": True},
    "history": [{
        "id": "snap-demo-1", "calculatedAt": "2026-08-08T09:30:00.000",
        "oldRent": 38000, "calculatedRent": 50122, "tufeRatePercent": 31.9,
        "applicableRatePercent": 31.9, "tufeReferenceMonth": "2026-08",
        "increaseDate": "2026-08-15T00:00:00.000", "contractRatePercent": None,
        "isFiveYearsOrMore": False,
    }],
}]


def adb(*a):
    return subprocess.run([ADB, "-s", EMU, *a], check=False, text=True,
                          capture_output=True, encoding="utf-8", errors="replace", timeout=60)


def log(m): print(m.encode("ascii", "replace").decode("ascii"), flush=True)


def dump():
    adb("shell", "uiautomator", "dump", "/sdcard/ui_shot.xml")
    p = TMP / "cur.xml"
    adb("pull", "/sdcard/ui_shot.xml", str(p))
    return p


def nodes(xml):
    raw = xml.read_text(encoding="utf-8", errors="replace")
    out = []
    for m in re.finditer(r"<node [^>]+/?>", raw):
        s = m.group(0)
        dm = re.search(r'content-desc="([^"]*)"', s)
        tm = re.search(r'text="([^"]*)"', s)
        bm = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', s)
        if not bm: continue
        x1,y1,x2,y2 = map(int, bm.groups())
        out.append({"desc": (dm.group(1) if dm else "").replace("&#10;","\n"),
                    "text": (tm.group(1) if tm else "").replace("&#10;","\n"),
                    "cx": (x1+x2)//2, "cy": (y1+y2)//2})
    return out


def blob(xml=None):
    return "\n".join(f"{n['text']}\n{n['desc']}" for n in nodes(xml or dump()))


def tap(x,y): adb("shell","input","tap",str(x),str(y))


def shot(name):
    dest = OUT / name
    adb("shell","screencap","-p","/sdcard/play_shot.png")
    adb("pull","/sdcard/play_shot.png", str(dest))
    log(f"SAVED {name} {dest.stat().st_size}")


def launch():
    adb("shell","monkey","-p",PKG,"-c","android.intent.category.LAUNCHER","1")
    time.sleep(4)


def seed():
    rj = json.dumps(DEMO, ensure_ascii=False, separators=(",",":"))
    rj = rj.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")
    xml = f"""<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
 <boolean name="flutter.onboarding_done" value="true" />
 <boolean name="flutter.is_pro_lifetime" value="true" />
 <boolean name="flutter.review_access_enabled" value="true" />
 <string name="flutter.rentals_v1">{rj}</string>
</map>"""
    local = TMP / "FlutterSharedPreferences.xml"
    local.write_text(xml, encoding="utf-8")
    adb("shell","am","force-stop",PKG)
    adb("shell","pm","clear",PKG)
    time.sleep(1)
    adb("shell","run-as",PKG,"mkdir","-p","shared_prefs")
    adb("push",str(local),"/data/local/tmp/FlutterSharedPreferences.xml")
    adb("shell", f"run-as {PKG} cp /data/local/tmp/FlutterSharedPreferences.xml shared_prefs/FlutterSharedPreferences.xml")
    adb("shell","settings","put","system","show_touches","0")
    adb("shell","settings","put","system","pointer_location","0")
    launch()


def click(pat, max_cy=2100, lowest=False):
    rx = re.compile(pat, re.I)
    cands = [n for n in nodes(dump()) if n["cy"]<=max_cy and (rx.search(n["text"]) or rx.search(n["desc"]))]
    if not cands:
        log(f"MISS {pat}")
        return False
    cands.sort(key=lambda n: n["cy"], reverse=lowest)
    n = cands[0]
    log(f"click {n['cx']},{n['cy']}")
    tap(n["cx"], n["cy"])
    time.sleep(1)
    return True


def wait(pat, t=10):
    rx = re.compile(pat, re.I)
    end = time.time()+t
    while time.time()<end:
        if rx.search(blob()): return True
        time.sleep(0.4)
    return False


def swipe():
    adb("shell","input","swipe","540","1550","540","850","280")
    time.sleep(0.4)


def main():
    log("=== missing shots ===")
    seed()
    wait(r"Hesapla|Kiralar|Konut", 12)

    # Open Ev detail
    tap(*NAV["Kiralarım"]); time.sleep(1.2)
    wait(r"Ev|38", 8)
    click(r"38\.000|38,000|Ev", max_cy=1200)
    time.sleep(1.2)
    if not wait(r"Kira Detay|PDF Raporu|Yeni d", 6):
        tap(540, 799); time.sleep(1.2)
    shot("05_kira_detayi.png")
    shot("06_kira_detayi_pdf.png")

    # 01 via Yeni donemi hesapla
    if not click(r"Yeni d.nemi hesapla", max_cy=1700):
        click(r"hesapla", max_cy=1500)
    time.sleep(1.5)
    wait(r"38000|38", 5)
    shot("01_hesapla.png")

    # 02 calculate
    cands = [n for n in nodes(dump()) if n["cy"]<2100 and (n["text"]=="Hesapla" or n["desc"].split("\n")[0]=="Hesapla")]
    if cands:
        cands.sort(key=lambda n: n["cy"], reverse=True)
        tap(cands[0]["cx"], cands[0]["cy"])
    else:
        tap(540, 1800)
    time.sleep(3)
    for _ in range(5):
        b = blob()
        if "PDF" in b and ("Payla" in b or "Kopyala" in b):
            break
        swipe()
    shot("02_sonuc.png")

    # 09 sheet
    if click(r"PDF Raporu", max_cy=2000, lowest=True):
        time.sleep(1.2)
        wait(r"Cihaza Kaydet", 5)
        shot("09_pdf_sheet.png")
        if click(r"Cihaza Kaydet", max_cy=2200):
            time.sleep(1.5)
            # SAF may open — back to app then show share instead
            adb("shell","input","keyevent","KEYCODE_BACK")
            time.sleep(0.8)
            # reopen sheet
            if "Cihaza" not in blob():
                click(r"PDF Raporu", max_cy=2000, lowest=True)
                time.sleep(1)
            click(r"^Payla|Payla.", max_cy=2300, lowest=True)
            time.sleep(2.5)
            shot("10_pdf_success_or_share.png")
        else:
            click(r"Payla", max_cy=2300, lowest=True)
            time.sleep(2.5)
            shot("10_pdf_success_or_share.png")
    else:
        log("no PDF button")

    log("DONE")
    for p in sorted(OUT.glob("*.png")):
        log(f"  {p.name} {p.stat().st_size}")


if __name__ == "__main__":
    main()
