# -*- coding: utf-8 -*-
"""Play Store ham screenshot yakalama — emulator-5554."""
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

# NavBar centers @ 1080x2400 (from uiautomator)
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
    line = msg.encode("ascii", "replace").decode("ascii")
    print(line, flush=True)


def dump_ui(name: str) -> Path:
    adb("shell", "uiautomator", "dump", "/sdcard/ui_shot.xml")
    xml = TMP / f"{name}.xml"
    adb("pull", "/sdcard/ui_shot.xml", str(xml))
    return xml


def screencap(filename: str) -> Path:
    dest = OUT / filename
    adb("shell", "screencap", "-p", "/sdcard/play_shot.png")
    adb("pull", "/sdcard/play_shot.png", str(dest))
    log(f"  SAVED {dest.name} size={dest.stat().st_size}")
    return dest


def nodes(xml_path: Path) -> list[dict]:
    raw = xml_path.read_text(encoding="utf-8", errors="replace")
    out: list[dict] = []
    for m in re.finditer(r"<node [^>]+/?>", raw):
        s = m.group(0)
        dm = re.search(r'content-desc="([^"]*)"', s)
        tm = re.search(r'text="([^"]*)"', s)
        bm = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', s)
        cm = re.search(r'class="([^"]*)"', s)
        if not bm:
            continue
        x1, y1, x2, y2 = map(int, bm.groups())
        desc = (dm.group(1) if dm else "").replace("&#10;", "\n")
        text = (tm.group(1) if tm else "").replace("&#10;", "\n")
        out.append(
            {
                "desc": desc,
                "text": text,
                "cls": cm.group(1) if cm else "",
                "cx": (x1 + x2) // 2,
                "cy": (y1 + y2) // 2,
                "y1": y1,
                "y2": y2,
            }
        )
    return out


def ui_blob(xml_path: Path) -> str:
    parts = []
    for n in nodes(xml_path):
        parts.append(n["text"])
        parts.append(n["desc"])
    return "\n".join(parts)


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))


def click_pattern(xml_path: Path, pattern: str) -> bool:
    rx = re.compile(pattern, re.I | re.M)
    cands = []
    for n in nodes(xml_path):
        for val in (n["desc"], n["text"]):
            if rx.search(val):
                cands.append(n)
                break
    if not cands:
        log(f"  MISS {pattern}")
        return False
    # Prefer lower on screen for action buttons
    cands.sort(key=lambda n: n["cy"], reverse=True)
    n = cands[0]
    log(f"  click [{(n['desc'] or n['text'])[:60]}] @ {n['cx']},{n['cy']}")
    tap(n["cx"], n["cy"])
    return True


def nav(tab: str) -> None:
    x, y = NAV[tab]
    log(f"  nav {tab} @ {x},{y}")
    tap(x, y)
    time.sleep(0.9)


def wait_blob(pattern: str, timeout: float = 12.0) -> Path:
    rx = re.compile(pattern, re.I)
    last = dump_ui("wait")
    deadline = time.time() + timeout
    while time.time() < deadline:
        last = dump_ui("wait")
        if rx.search(ui_blob(last)):
            return last
        time.sleep(0.4)
    return last


def swipe_up(dy: int = 800) -> None:
    adb("shell", "input", "swipe", "540", "1700", "540", str(1700 - dy), "300")


def back(n: int = 1) -> None:
    for _ in range(n):
        adb("shell", "input", "keyevent", "KEYCODE_BACK")
        time.sleep(0.45)


def type_text(text: str) -> None:
    adb("shell", "input", "text", text.replace(" ", "%s"))


def clear_field() -> None:
    for _ in range(20):
        adb("shell", "input", "keyevent", "KEYCODE_DEL")


def prepare_system() -> None:
    adb("shell", "settings", "put", "system", "show_touches", "0")
    adb("shell", "settings", "put", "system", "pointer_location", "0")
    # Keep status bar for Play phone frames; hide touch indicators only.


def seed_prefs() -> None:
    rentals_json = json.dumps(DEMO_RENTALS, ensure_ascii=False, separators=(",", ":"))
    # Do NOT entity-escape quotes — Android SP XML text content needs real quotes.
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
    v = adb("shell", "run-as", PKG, "cat", "shared_prefs/FlutterSharedPreferences.xml")
    log(f"  seed ok bytes={len(v.stdout)} pro={'is_pro_lifetime' in v.stdout}")


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
    time.sleep(4.0)


def dismiss_ump() -> None:
    for attempt in range(8):
        xml = dump_ui(f"ump{attempt}")
        blob = ui_blob(xml)
        if re.search(r"Consent|Do not consent|Kabul|Manage options", blob, re.I):
            log(f"  UMP visible attempt={attempt}")
            if click_pattern(xml, r"^Consent$") or click_pattern(xml, r"\bConsent\b"):
                time.sleep(2.0)
                continue
            if click_pattern(xml, r"Do not consent"):
                time.sleep(2.0)
                continue
            # Fallback approximate button coords for test form
            tap(540, 1680)  # Consent-ish
            time.sleep(2.0)
            continue
        if re.search(r"Hesapla|Konut|Oranlar|Ayarlar", blob):
            log("  UMP gone / home ready")
            return
        time.sleep(0.6)
    log("  UMP dismiss timed out — continue")


def fill_rent_38000() -> None:
    xml = dump_ui("form")
    # Tap "Mevcut aylık kira" area — EditText often inside semantics merge
    # Approximate: first field ~ y 520-620
    edits = [n for n in nodes(xml) if "EditText" in n["cls"]]
    if edits:
        tap(edits[0]["cx"], edits[0]["cy"])
    else:
        # Tap near top of form card
        tap(540, 560)
    time.sleep(0.35)
    clear_field()
    type_text("38000")
    time.sleep(0.3)
    adb("shell", "input", "keyevent", "KEYCODE_BACK")  # hide keyboard
    time.sleep(0.4)


def tap_hesapla_button() -> None:
    xml = dump_ui("calc_btn")
    # Prefer exact Hesapla button (not tab) — usually higher cy than tab? Tab is lower.
    # Tab cy~2242, button cy~1800
    cands = [
        n
        for n in nodes(xml)
        if re.search(r"^Hesapla$", n["desc"].split("\n")[0])
        or n["text"] == "Hesapla"
    ]
    cands = [n for n in cands if n["cy"] < 2100]
    if cands:
        cands.sort(key=lambda n: n["cy"], reverse=True)
        n = cands[0]
        log(f"  Hesapla btn @ {n['cx']},{n['cy']}")
        tap(n["cx"], n["cy"])
        return
    if click_pattern(xml, r"^Hesapla$"):
        return
    tap(540, 1800)


def ensure_visible(patterns: list[str], swipes: int = 4) -> None:
    for _ in range(swipes):
        blob = ui_blob(dump_ui("vis"))
        if all(re.search(p, blob, re.I) for p in patterns):
            return
        swipe_up(650)
        time.sleep(0.35)


def main() -> None:
    log("=== Play raw screenshots ===")
    prepare_system()
    seed_prefs()
    launch()
    dismiss_ump()
    time.sleep(1.0)

    # 01 Hesapla filled
    log("01 Hesapla")
    nav("Hesapla")
    fill_rent_38000()
    time.sleep(0.5)
    screencap("01_hesapla.png")

    # 02 Sonuc from rental (Yeni kirayi kaydet)
    log("02 Sonuc")
    nav("Kiralarım")
    time.sleep(0.8)
    xml = wait_blob(r"\bEv\b", 8)
    if not click_pattern(xml, r"^Ev$") and not click_pattern(xml, r"\bEv\b"):
        log("  Ev missing — fallback Hesapla calc")
        nav("Hesapla")
        fill_rent_38000()
        tap_hesapla_button()
        time.sleep(2.5)
        wait_blob(r"50122|50\.?122|BU ORANA|Art", 12)
        ensure_visible([r"Payla", r"Kopyala", r"PDF"])
        screencap("02_sonuc.png")
    else:
        time.sleep(1.0)
        xml = wait_blob(r"Hesapla|PDF|38", 8)
        # Tap Hesapla CTA on detail (not nav)
        cands = [
            n
            for n in nodes(xml)
            if "Hesapla" in (n["desc"] + n["text"]) and n["cy"] < 2100
        ]
        if cands:
            cands.sort(key=lambda n: n["cy"])
            tap(cands[0]["cx"], cands[0]["cy"])
        else:
            click_pattern(xml, r"Hesapla")
        time.sleep(1.2)
        tap_hesapla_button()
        time.sleep(2.5)
        wait_blob(r"50122|50\.?122|BU ORANA|Art", 12)
        ensure_visible([r"Yeni kiray|Kiralar.ma Kaydet", r"Payla", r"Kopyala", r"PDF"])
        screencap("02_sonuc.png")
        back(2)

    # 03 Oranlar
    log("03 Oranlar")
    nav("Oranlar")
    time.sleep(1.0)
    wait_blob(r"31|T.FE|Oran", 8)
    screencap("03_oranlar.png")

    # 04 Kiralarim
    log("04 Kiralarim")
    nav("Kiralarım")
    time.sleep(1.0)
    wait_blob(r"Ev|Kiralar", 6)
    screencap("04_kiralarim.png")

    # 05 Detail
    log("05 Detail")
    xml = dump_ui("klist")
    click_pattern(xml, r"\bEv\b")
    time.sleep(1.0)
    wait_blob(r"Ev|38|Hesapla|ge.mi.", 8)
    screencap("05_kira_detayi.png")

    # 06 Detail PDF button
    log("06 Detail PDF")
    ensure_visible([r"PDF"], swipes=3)
    screencap("06_kira_detayi_pdf.png")

    # 07 Reminder
    log("07 Reminder")
    back(1)
    nav("Ayarlar")
    time.sleep(0.8)
    xml = dump_ui("set")
    click_pattern(xml, r"Yenileme Hat.rlatmas.|Hat.rlatma")
    time.sleep(1.2)
    xml = wait_blob(r"30 g.n|7 g.n|Ev|Hat.rlat", 8)
    if "30" not in ui_blob(xml) and re.search(r"\bEv\b", ui_blob(xml)):
        click_pattern(xml, r"\bEv\b")
        time.sleep(1.0)
    ensure_visible([r"30", r"7"], swipes=2)
    screencap("07_hatirlatma.png")

    # 08 Settings Pro
    log("08 Settings Pro")
    back(1)
    nav("Ayarlar")
    time.sleep(1.0)
    wait_blob(r"Pro aktif|Ayarlar|Gizlilik", 8)
    screencap("08_ayarlar_pro.png")

    # 09 PDF sheet
    log("09 PDF sheet")
    nav("Kiralarım")
    time.sleep(0.7)
    click_pattern(dump_ui("k2"), r"\bEv\b")
    time.sleep(0.8)
    ensure_visible([r"PDF"], 3)
    xml = dump_ui("pdfbtn")
    click_pattern(xml, r"PDF Raporu|PDF")
    time.sleep(1.0)
    wait_blob(r"Cihaza Kaydet|Payla", 6)
    screencap("09_pdf_sheet.png")

    # 10 Share
    log("10 Share")
    xml = dump_ui("sheet")
    if click_pattern(xml, r"^Payla.$") or click_pattern(xml, r"Payla"):
        time.sleep(2.2)
    screencap("10_pdf_success_or_share.png")

    log("=== DONE ===")
    for p in sorted(OUT.glob("*.png")):
        log(f"  {p.name} {p.stat().st_size}")


if __name__ == "__main__":
    main()
