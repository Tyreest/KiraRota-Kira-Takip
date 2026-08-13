# -*- coding: utf-8 -*-
"""Live smoke automation for Kira Asistanı on emulator."""
from __future__ import annotations

import re
import subprocess
import time
from pathlib import Path

ADB = str(Path.home() / "AppData/Local/Android/Sdk/platform-tools/adb.exe")
EMU = "emulator-5554"
OUT = Path(r"C:\Users\yigit\Desktop\Projeler\kira-artisi-hesapla\store\live_smoke")
PKG = "com.tyreest.kiraartisi"
OUT.mkdir(parents=True, exist_ok=True)


def adb(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [ADB, "-s", EMU, *args],
        check=False,
        text=True,
        capture_output=True,
        encoding="utf-8",
        errors="replace",
    )


def dump(name: str) -> Path:
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    xml = OUT / f"{name}.xml"
    adb("pull", "/sdcard/ui.xml", str(xml))
    adb("shell", "screencap", "-p", "/sdcard/smoke.png")
    png = OUT / f"{name}.png"
    adb("pull", "/sdcard/smoke.png", str(png))
    print(f"saved {name}")
    return xml


def descs(xml_path: Path) -> list[str]:
    raw = xml_path.read_text(encoding="utf-8", errors="replace")
    return [d.replace("\n", " | ") for d in re.findall(r'content-desc="([^"]*)"', raw) if d.strip()]


def nodes(xml_path: Path) -> list[dict]:
    raw = xml_path.read_text(encoding="utf-8", errors="replace")
    out = []
    for m in re.finditer(r"<node [^>]+>", raw):
        s = m.group(0)
        dm = re.search(r'content-desc="([^"]*)"', s)
        bm = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', s)
        cm = re.search(r'class="([^"]*)"', s)
        if not bm:
            continue
        x1, y1, x2, y2 = map(int, bm.groups())
        out.append(
            {
                "desc": dm.group(1) if dm else "",
                "cls": cm.group(1) if cm else "",
                "cx": (x1 + x2) // 2,
                "cy": (y1 + y2) // 2,
                "bounds": (x1, y1, x2, y2),
            }
        )
    return out


def click_desc(xml_path: Path, pattern: str) -> bool:
    rx = re.compile(pattern)
    for n in nodes(xml_path):
        if rx.search(n["desc"]):
            safe_print(f"OK click [{n['desc'][:70]}] @ {n['cx']},{n['cy']}")
            adb("shell", "input", "tap", str(n["cx"]), str(n["cy"]))
            return True
    safe_print(f"MISS {pattern}")
    return False


def click_edittext(xml_path: Path, index: int = 0) -> bool:
    edits = [n for n in nodes(xml_path) if "EditText" in n["cls"]]
    if index >= len(edits):
        safe_print(f"MISS EditText[{index}] count={len(edits)}")
        return False
    n = edits[index]
    safe_print(f"OK EditText[{index}] @ {n['cx']},{n['cy']}")
    adb("shell", "input", "tap", str(n["cx"]), str(n["cy"]))
    return True


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))


def safe_print(msg: str) -> None:
    try:
        print(msg)
    except UnicodeEncodeError:
        print(msg.encode("ascii", "replace").decode("ascii"))


def report(title: str, xml: Path) -> None:
    safe_print(f"\n=== {title} ===")
    for d in descs(xml):
        safe_print(f" - {d}")


def main() -> None:
    results: list[tuple[str, str]] = []

    adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(1.2)

    # Onboarding if present
    boot = dump("20_boot")
    report("BOOT", boot)
    if any(d == "Başla" for d in descs(boot)):
        click_desc(boot, r"^Başla$")
        time.sleep(1.2)
        results.append(("Onboarding Başla", "PASS"))
    else:
        results.append(("Onboarding (zaten geçmiş)", "PASS"))

    home = dump("21_home")
    report("HOME", home)
    home_ok = any("Hesapla" in d for d in descs(home)) and any("Konut" in d for d in descs(home))
    results.append(("Ana ekran (Hesapla/Konut)", "PASS" if home_ok else "FAIL"))

    # Fill rent amount (first EditText)
    if not click_edittext(home, 0):
        tap(540, 660)
    time.sleep(0.5)
    for _ in range(20):
        adb("shell", "input", "keyevent", "KEYCODE_DEL")
    adb("shell", "input", "text", "25000")
    time.sleep(0.5)
    adb("shell", "input", "keyevent", "4")
    time.sleep(0.6)

    filled = dump("22_filled")
    report("FILLED", filled)
    click_desc(filled, r"^Hesapla$")
    time.sleep(2.2)
    result = dump("23_result")
    report("RESULT", result)
    rd = " | ".join(descs(result)).lower()
    calc_ok = any(
        k in rd
        for k in (
            "azami",
            "hesaplanan",
            "sonuç",
            "sonuc",
            "yeni kira",
            "oran",
            "%",
            "kopyala",
            "paylaş",
            "paylas",
            "pdf",
        )
    )
    results.append(("Hesapla → sonuç", "PASS" if calc_ok else "FAIL"))

    # Dismiss result if route
    if calc_ok:
        if any("Geri" in d or "Close" in d or "Kapat" in d for d in descs(result)):
            click_desc(result, r"Geri|Kapat|Close")
        else:
            adb("shell", "input", "keyevent", "4")
        time.sleep(0.8)

    # Tabs
    for label, pattern, fname, keywords in [
        ("Oranlar sekmesi", r"Oranlar", "24_oranlar", ("oran", "tüfe", "tufe", "%", "yeni")),
        ("Geçmiş sekmesi", r"Geçmiş|Gecmis", "25_gecmis", ("geçmiş", "gecmis", "boş", "bos", "hesap", "kayıt", "kayit", "yeni")),
        ("Ayarlar sekmesi", r"Ayarlar", "26_ayarlar", ("ayar", "pro", "gizlilik", "yasal", "kullanım", "kullanim", "yükselt", "yukselt")),
        ("Hesapla sekmesi", r"Hesapla\|Tab|Hesapla\nTab", "27_hesapla_tab", ("kira", "konut", "hesapla")),
    ]:
        cur = dump("tmp_nav")
        click_desc(cur, pattern)
        time.sleep(1.0)
        xml = dump(fname)
        report(fname, xml)
        blob = " | ".join(descs(xml)).lower()
        ok = any(k in blob for k in keywords)
        results.append((label, "PASS" if ok else "FAIL"))

    # Free PDF / paywall from result if we can recalculate quickly
    cur = dump("tmp_pdf")
    click_desc(cur, r"^Hesapla$")
    time.sleep(1.5)
    res2 = dump("28_result_again")
    if click_desc(res2, r"PDF|pdf"):
        time.sleep(1.2)
        pay = dump("29_pdf_paywall")
        report("PDF", pay)
        blob = " | ".join(descs(pay)).lower()
        results.append(
            (
                "Free PDF → paywall/pro",
                "PASS" if any(k in blob for k in ("pro", "satın", "satin", "yükselt", "yukselt", "lifetime", "ömür", "omur")) else "CHECK",
            )
        )
        adb("shell", "input", "keyevent", "4")
        time.sleep(0.5)
    else:
        results.append(("Free PDF butonu", "CHECK"))

    # Log signals
    log = adb("logcat", "-d", "-t", "400")
    text = log.stdout or ""
    ads_test = ("test device" in text.lower()) or ("googleads" in text.lower()) or ("Ads" in text)
    billing_emu = "billing API version 3 is not supported" in text
    fatal = ("FATAL EXCEPTION" in text) and (PKG.replace(".", "") in text.replace(".", "") or "kiraartisi" in text)
    results.append(("AdMob test isteği (log)", "PASS" if ads_test else "WARN"))
    results.append(("Play Billing (emulator)", "EXPECTED-FAIL" if billing_emu else "N/A"))
    results.append(("Crash yok", "FAIL" if fatal else "PASS"))

    # Cold start branding
    adb("shell", "am", "force-stop", PKG)
    time.sleep(0.4)
    adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(2.0)
    cold = dump("30_cold_start")
    report("COLD", cold)
    cold_ok = any("Kira" in d or "Hesapla" in d or "Konut" in d for d in descs(cold))
    results.append(("Cold start", "PASS" if cold_ok else "FAIL"))

    safe_print("\n======== LIVE SMOKE SUMMARY ========")
    for k, v in results:
        safe_print(f"{v:14}  {k}")
    (OUT / "SUMMARY.txt").write_text(
        "\n".join(f"{v}\t{k}" for k, v in results) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
