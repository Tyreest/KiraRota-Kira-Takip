# -*- coding: utf-8 -*-
import re
import subprocess
import time
from pathlib import Path

ADB = str(Path.home() / "AppData/Local/Android/Sdk/platform-tools/adb.exe")
EMU = "emulator-5554"
OUT = Path(r"C:\Users\yigit\Desktop\Projeler\kira-artisi-hesapla\store\live_smoke")
PKG = "com.tyreest.kiraartisi"


def adb(*a):
    return subprocess.run(
        [ADB, "-s", EMU, *a],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def dump(name):
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    p = OUT / f"{name}.xml"
    adb("pull", "/sdcard/ui.xml", str(p))
    adb("shell", "screencap", "-p", "/sdcard/smoke.png")
    adb("pull", "/sdcard/smoke.png", str(OUT / f"{name}.png"))
    print("saved", name)
    return p


def nodes(p):
    raw = p.read_text(encoding="utf-8", errors="replace")
    out = []
    for m in re.finditer(r"<node [^>]+>", raw):
        s = m.group(0)
        dm = re.search(r'content-desc="([^"]*)"', s)
        tm = re.search(r'text="([^"]*)"', s)
        bm = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', s)
        if not bm:
            continue
        x1, y1, x2, y2 = map(int, bm.groups())
        out.append(
            {
                "desc": dm.group(1) if dm else "",
                "text": tm.group(1) if tm else "",
                "cx": (x1 + x2) // 2,
                "cy": (y1 + y2) // 2,
            }
        )
    return out


def click_any(p, pattern):
    rx = re.compile(pattern, re.I)
    for n in nodes(p):
        blob = f"{n['desc']} {n['text']}"
        if rx.search(blob):
            print("OK", blob[:60], n["cx"], n["cy"])
            adb("shell", "input", "tap", str(n["cx"]), str(n["cy"]))
            return True
    print("MISS", pattern)
    return False


def main():
    cur = dump("60_now")
    blob = " ".join(f"{n['desc']} {n['text']}" for n in nodes(cur)).lower()
    if "interstitial" in blob or "got it" in blob or "viewing full screen" in blob:
        print("Dismiss interstitial")
        if not click_any(cur, r"Got it|Close|close|Kapat"):
            # swipe down from top as instructed
            adb("shell", "input", "swipe", "540", "80", "540", "900", "400")
        time.sleep(1.0)
        # try close X typical top right
        adb("shell", "input", "tap", "990", "160")
        time.sleep(1.0)
        cur = dump("61_after_ad")

    # If still on form/result
    if not any("PDF" in n["desc"] for n in nodes(cur)):
        if any(n["desc"] == "Hesapla" for n in nodes(cur)):
            # may need fill - check EditText value via dump texts
            raw = cur.read_text(encoding="utf-8", errors="replace")
            edits = list(
                re.finditer(
                    r'class="android.widget.EditText"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
                    raw,
                )
            )
            if edits:
                x1, y1, x2, y2 = map(int, edits[0].groups())
                adb("shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))
                time.sleep(0.2)
                for _ in range(20):
                    adb("shell", "input", "keyevent", "67")
                adb("shell", "input", "text", "25000")
                adb("shell", "input", "keyevent", "4")
                time.sleep(0.4)
            cur = dump("62_filled")
            click_any(cur, r"^Hesapla$")
            time.sleep(2.5)
            cur = dump("63_result")
            # dismiss interstitial if shown again
            blob = " ".join(f"{n['desc']} {n['text']}" for n in nodes(cur)).lower()
            if "interstitial" in blob or "got it" in blob:
                click_any(cur, r"Got it|Close|close")
                time.sleep(0.8)
                adb("shell", "input", "tap", "990", "160")
                time.sleep(1.0)
                cur = dump("64_result2")

    adb("shell", "input", "swipe", "540", "1700", "540", "900", "300")
    time.sleep(0.5)
    cur = dump("65_before_pdf")
    for n in nodes(cur):
        if n["desc"]:
            print("-", n["desc"].replace("\n", " | ")[:100])
    ok = click_any(cur, r"PDF|Raporu")
    time.sleep(1.5)
    pay = dump("66_paywall")
    descs = [n["desc"] for n in nodes(pay) if n["desc"]]
    print("---PAYWALL---")
    for d in descs:
        print(d.replace("\n", " | "))
    blob = " ".join(descs).lower()
    passed = any(
        k in blob
        for k in (
            "pro",
            "satın",
            "satin",
            "yükselt",
            "yukselt",
            "ömür",
            "omur",
            "geri yükle",
            "restore",
            "mağaza",
            "magaza",
            "kira asistanı pro",
        )
    )
    print("PDF_PAYWALL", "PASS" if passed else "FAIL", "click", ok)
    (OUT / "SUMMARY_PDF.txt").write_text(
        f"{'PASS' if passed else 'FAIL'}\tFree PDF paywall\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
