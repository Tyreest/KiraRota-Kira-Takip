import os
import re
import subprocess
import time

ID = "emulator-5554"
OUT = "docs/qa/branding"


def adb(*args: str) -> None:
    subprocess.check_call(["adb", "-s", ID, *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def dump() -> str:
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    subprocess.check_call(
        ["adb", "-s", ID, "pull", "/sdcard/ui.xml", f"{OUT}/_ui.xml"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    with open(f"{OUT}/_ui.xml", encoding="utf-8", errors="ignore") as f:
        return f.read()


def descs(xml: str) -> list[str]:
    return re.findall(r'content-desc="([^"]+)"', xml)


def tap_desc(xml: str, text: str) -> bool:
    for attr in ("content-desc", "text"):
        m = re.search(
            rf'{attr}="{re.escape(text)}"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
            xml,
        )
        if not m:
            m = re.search(
                rf'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"[^>]*{attr}="{re.escape(text)}"',
                xml,
            )
        if m:
            x = (int(m.group(1)) + int(m.group(3))) // 2
            y = (int(m.group(2)) + int(m.group(4))) // 2
            adb("shell", "input", "tap", str(x), str(y))
            print(f"tapped {text} @ {x},{y}")
            return True
    print(f"MISSING {text}")
    return False


def screenshot(name: str) -> None:
    data = subprocess.check_output(["adb", "-s", ID, "exec-out", "screencap", "-p"])
    path = os.path.join(OUT, name)
    with open(path, "wb") as f:
        f.write(data)
    print(f"shot {path} ({len(data)} bytes)")


def tap_contains(xml: str, needle: str) -> bool:
    for node in re.finditer(r"<node\b[^>]*>", xml):
        chunk = node.group(0)
        label_m = re.search(r'content-desc="([^"]*)"', chunk)
        if not label_m or not label_m.group(1):
            label_m = re.search(r'text="([^"]+)"', chunk)
        if not label_m:
            continue
        label = label_m.group(1).replace("&#10;", "\n")
        if needle not in label:
            continue
        bm = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', chunk)
        if not bm:
            continue
        x1, y1, x2, y2 = map(int, bm.groups())
        x = (x1 + x2) // 2
        y = (y1 + y2) // 2
        adb("shell", "input", "tap", str(x), str(y))
        print(f"tapped~{needle} ({label!r}) @ {x},{y}")
        return True
    print(f"MISSING~{needle}")
    return False


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    xml = dump()
    print("initial:", descs(xml)[:12])
    tap_desc(xml, "Başla")
    time.sleep(2.5)
    xml = dump()
    print("after basla:", [d for d in descs(xml) if d][:20])
    tap_contains(xml, "Ayarlar")
    time.sleep(1.5)
    for _ in range(5):
        adb("shell", "input", "swipe", "540", "1700", "540", "500", "300")
        time.sleep(0.35)
    xml = dump()
    labels = [d.replace("&#10;", "\n") for d in descs(xml)]
    found = [d for d in labels if any(k in d for k in ("Yedek", "JSON", "Veri", "Ayarlar"))]
    print("settings found:", found)
    with open(f"{OUT}/_backup_settings_descs.txt", "w", encoding="utf-8") as f:
        f.write("\n".join(labels))
    screenshot("backup_settings.png")
    assert any("Yedek oluştur" in d for d in labels), "Yedek oluştur görünmüyor"
    assert not any("JSON" in d for d in labels), "UI'da JSON kelimesi var"
    tap_contains(xml, "Yedek oluştur")
    time.sleep(1.8)
    xml = dump()
    labels = [d.replace("&#10;", "\n") for d in descs(xml)]
    print("sheet:", labels[:40])
    screenshot("backup_ready.png")
    assert any("Yedek hazır" in d for d in labels)
    assert any("Cihaza Kaydet" in d for d in labels)
    assert any("Paylaş" in d for d in labels)
    tap_contains(xml, "Paylaş")
    time.sleep(2.5)
    screenshot("backup_share_sheet.png")
    xml = dump()
    texts = [
        t.replace("&#10;", "\n")
        for t in re.findall(r'(?:content-desc|text)="([^"]+)"', xml)
    ]
    interesting = [
        t
        for t in texts
        if any(
            k in t.lower()
            for k in ("json", "kirarota", "yedek", "{", "exportedat", "rentals")
        )
        or "JSON" in t
    ]
    print("share interesting:", interesting[:50])
    raw_json_shown = any('"rentals"' in t or t.strip().startswith("{") for t in texts)
    assert not raw_json_shown, "Share sheet'te ham JSON görünüyor"
    file_hint = any(".json" in t.lower() or "kirarota-yedek" in t.lower() for t in texts)
    print("file_hint:", file_hint)
    adb("shell", "input", "keyevent", "4")
    print("SMOKE_OK")


if __name__ == "__main__":
    main()
