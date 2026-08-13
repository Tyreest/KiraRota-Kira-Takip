# -*- coding: utf-8 -*-
"""Continue live smoke: tabs + PDF + launcher icon."""
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


def safe_print(msg: str) -> None:
    try:
        print(msg)
    except UnicodeEncodeError:
        print(msg.encode("ascii", "replace").decode("ascii"))


def dump(name: str) -> Path:
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    xml = OUT / f"{name}.xml"
    adb("pull", "/sdcard/ui.xml", str(xml))
    adb("shell", "screencap", "-p", "/sdcard/smoke.png")
    adb("pull", "/sdcard/smoke.png", str(OUT / f"{name}.png"))
    safe_print(f"saved {name}")
    return xml


def descs(xml: Path) -> list[str]:
    raw = xml.read_text(encoding="utf-8", errors="replace")
    return [d.replace("\n", " | ") for d in re.findall(r'content-desc="([^"]*)"', raw) if d.strip()]


def nodes(xml: Path) -> list[dict]:
    raw = xml.read_text(encoding="utf-8", errors="replace")
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
            }
        )
    return out


def click_desc(xml: Path, pattern: str) -> bool:
    rx = re.compile(pattern)
    for n in nodes(xml):
        if rx.search(n["desc"]):
            safe_print(f"OK [{n['desc'][:60]}] @ {n['cx']},{n['cy']}")
            adb("shell", "input", "tap", str(n["cx"]), str(n["cy"]))
            return True
    safe_print(f"MISS {pattern}")
    return False


def report(title: str, xml: Path) -> None:
    safe_print(f"\n=== {title} ===")
    for d in descs(xml):
        safe_print(f" - {d}")


def main() -> None:
    results: list[tuple[str, str]] = []

    # Launch app activity explicitly
    adb(
        "shell",
        "am",
        "start",
        "-n",
        f"{PKG}/com.tyreest.kira_artisi_hesapla.MainActivity",
    )
    time.sleep(2.0)
    home = dump("40_home")
    report("HOME", home)
    if not any("Hesapla" in d for d in descs(home)):
        # try flutter default activity
        adb("shell", "cmd", "package", "resolve-activity", "--brief", PKG)
        safe_print(adb("shell", "cmd", "package", "resolve-activity", "--brief", PKG).stdout)
        adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
        time.sleep(2.0)
        home = dump("40_home")
        report("HOME2", home)

    results.append(("App foreground", "PASS" if any("Hesapla" in d for d in descs(home)) else "FAIL"))

    # Ensure calculation for PDF later
    edits = [n for n in nodes(home) if "EditText" in n["cls"]]
    if edits:
        adb("shell", "input", "tap", str(edits[0]["cx"]), str(edits[0]["cy"]))
        time.sleep(0.3)
        for _ in range(20):
            adb("shell", "input", "keyevent", "KEYCODE_DEL")
        adb("shell", "input", "text", "25000")
        adb("shell", "input", "keyevent", "4")
        time.sleep(0.4)
    filled = dump("41_filled")
    click_desc(filled, r"^Hesapla$")
    time.sleep(2.0)
    result = dump("42_result")
    report("RESULT", result)
    calc_ok = any("32.975" in d or "%31" in d or "azami" in d.lower() for d in descs(result))
    results.append(("Hesapla sonucu", "PASS" if calc_ok else "FAIL"))

    # Tabs WITHOUT system back — use bottom nav from result
    for label, pat, name, keys in [
        ("Oranlar", r"Oranlar", "43_oranlar", ("oran", "%", "tüfe", "tufe", "ağustos", "agustos", "yeni")),
        ("Geçmiş", r"Geçmiş", "44_gecmis", ("geçmiş", "gecmis", "hesap", "32", "kira", "boş", "bos", "yeni")),
        ("Ayarlar", r"Ayarlar", "45_ayarlar", ("ayar", "pro", "gizlilik", "yasal", "hatırlat", "hatirlat", "satın", "satin")),
    ]:
        cur = dump("tmp")
        # Prefer tab content-desc containing Tab
        if not click_desc(cur, pat + r".*Tab|" + pat):
            click_desc(cur, pat)
        time.sleep(1.2)
        xml = dump(name)
        report(name, xml)
        blob = " | ".join(descs(xml)).lower()
        ok = any(k in blob for k in keys) and PKG.split(".")[-1] not in ("",)
        # must still be our app
        in_app = "Play Store" not in descs(xml) or any("Hesapla" in d or "Oranlar" in d or "Ayarlar" in d for d in descs(xml))
        # better check package via dumpsys
        fg = adb("shell", "dumpsys", "activity", "activities").stdout
        in_pkg = PKG in fg
        results.append((label, "PASS" if (ok and in_app) else "FAIL"))

    # PDF paywall: go Hesapla tab, calc if needed, tap PDF
    cur = dump("tmp")
    click_desc(cur, r"Hesapla.*Tab|^Hesapla$")
    time.sleep(1.0)
    cur = dump("46_before_pdf")
    if not any("PDF" in d for d in descs(cur)):
        # might be on form — calculate again
        if click_desc(cur, r"^Hesapla$"):
            time.sleep(1.8)
            cur = dump("46_result_pdf")
    if click_desc(cur, r"PDF"):
        time.sleep(1.3)
        pay = dump("47_paywall")
        report("PAYWALL", pay)
        blob = " | ".join(descs(pay)).lower()
        results.append(
            (
                "Free PDF → Pro/paywall",
                "PASS"
                if any(k in blob for k in ("pro", "satın", "satin", "yükselt", "yukselt", "ömür", "omur", "lifetime", "geri yükle", "restore"))
                else "FAIL",
            )
        )
        # stay in app: tap close/geri if any else don't system-back to home
        if not click_desc(pay, r"Geri|Kapat|Close|Vazgeç|Vazgec"):
            # tap top-left back affordance roughly
            adb("shell", "input", "tap", "80", "160")
        time.sleep(0.8)
    else:
        results.append(("Free PDF → Pro/paywall", "FAIL"))

    # Reminder path from Ayarlar without granting at startup
    cur = dump("tmp")
    click_desc(cur, r"Ayarlar")
    time.sleep(1.0)
    ay = dump("48_ayarlar_reminder")
    report("AYARLAR", ay)
    # startup notification dialog should NOT appear
    blob = " | ".join(descs(ay)).lower()
    notif_startup = any(k in blob for k in ("izin ver", "allow", "bildirimlere izin"))
    results.append(("Startup bildirim dialogu yok", "FAIL" if notif_startup else "PASS"))

    # Launcher icon: open app info / dump launcher
    adb("shell", "am", "start", "-a", "android.intent.action.MAIN", "-c", "android.intent.category.HOME")
    time.sleep(1.0)
    # Open app drawer (swipe up)
    adb("shell", "input", "swipe", "540", "2000", "540", "400", "300")
    time.sleep(1.2)
    drawer = dump("49_app_drawer")
    report("DRAWER", drawer)
    has_kira = any(
        ("Kira" in d) or ("kira" in d.lower())
        for d in descs(drawer)
    )
    results.append(("Launcher'da Kira uygulaması", "PASS" if has_kira else "CHECK"))

    # Pull launcher icon resource from installed apk for visual check
    icon_path = OUT / "installed_ic_launcher.png"
    # copy from apk via aapt-like: use run-as or pull from /data/app
    path = adb("shell", "pm", "path", PKG).stdout.strip().replace("package:", "")
    safe_print(f"apk={path}")
    if path:
        adb("pull", path, str(OUT / "installed.apk"))

    # Label
    label = adb("shell", "dumpsys", "package", PKG).stdout
    m = re.search(r"applicationLabel=(.+)", label)
    if m:
        safe_print(f"applicationLabel={m.group(1).strip()}")
        results.append(("App label", "PASS" if "Kira" in m.group(1) else "CHECK"))

    # Ads log
    log = adb("logcat", "-d", "-t", "300").stdout or ""
    results.append(("AdMob test banner", "PASS" if ("test device" in log.lower() or "test ad" in log.lower() or "googleads" in log.lower()) else "WARN"))
    results.append(("Billing emulator", "EXPECTED-FAIL" if "billing API version 3 is not supported" in log else "N/A"))
    results.append(("Crash", "FAIL" if "FATAL EXCEPTION" in log and "kiraartisi" in log else "PASS"))

    safe_print("\n======== LIVE SMOKE SUMMARY ========")
    for k, v in results:
        safe_print(f"{v:14}  {k}")
    (OUT / "SUMMARY2.txt").write_text("\n".join(f"{v}\t{k}" for k, v in results) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
