import re
import subprocess
import time

ID = "emulator-5554"
OUT = "docs/qa/branding"


def adb(*a: str) -> None:
    subprocess.check_call(
        ["adb", "-s", ID, *a], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )


def dump() -> str:
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    subprocess.check_call(
        ["adb", "-s", ID, "pull", "/sdcard/ui.xml", f"{OUT}/_ui.xml"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return open(f"{OUT}/_ui.xml", encoding="utf-8", errors="ignore").read()


def tap(xml: str, needle: str) -> bool:
    for node in re.finditer(r"<node\b[^>]*>", xml):
        chunk = node.group(0)
        lm = re.search(r'content-desc="([^"]*)"', chunk)
        if not lm or not lm.group(1):
            lm = re.search(r'text="([^"]+)"', chunk)
        if not lm:
            continue
        label = lm.group(1).replace("&#10;", "\n")
        if needle not in label:
            continue
        bm = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', chunk)
        if not bm:
            continue
        x1, y1, x2, y2 = map(int, bm.groups())
        x, y = (x1 + x2) // 2, (y1 + y2) // 2
        adb("shell", "input", "tap", str(x), str(y))
        print("tap", needle, repr(label), x, y)
        return True
    print("miss", needle)
    return False


def main() -> None:
    xml = dump()
    tap(xml, "Ayarlar")
    time.sleep(1)
    for _ in range(5):
        adb("shell", "input", "swipe", "540", "1700", "540", "500", "300")
        time.sleep(0.3)
    xml = dump()
    tap(xml, "Yedek oluştur")
    time.sleep(2)
    xml = dump()
    for node in re.finditer(r"<node\b[^>]*>", xml):
        if "Payla" in node.group(0):
            print(node.group(0)[:260])
    tap(xml, "Paylaş")
    time.sleep(3)
    data = subprocess.check_output(["adb", "-s", ID, "exec-out", "screencap", "-p"])
    open(f"{OUT}/backup_share_sheet.png", "wb").write(data)
    xml = dump()
    texts = [
        t.replace("&#10;", "\n")
        for t in re.findall(r'(?:content-desc|text)="([^"]+)"', xml)
    ]
    print("--- share ui ---")
    for t in texts:
        low = t.lower()
        if any(
            k in low
            for k in (
                "json",
                "kira",
                "yedek",
                "drive",
                "gmail",
                "nearby",
                "bluetooth",
                "copy",
                ".json",
                "files",
                "share",
            )
        ):
            print(repr(t)[:160])
    raw = any('"rentals"' in t or t.strip().startswith("{") for t in texts)
    print("raw_json", raw)
    print("has_json_filename", any(".json" in t.lower() for t in texts))
    adb("shell", "input", "keyevent", "4")


if __name__ == "__main__":
    main()
