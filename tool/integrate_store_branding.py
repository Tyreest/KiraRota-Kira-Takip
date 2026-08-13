# -*- coding: utf-8 -*-
"""DEPRECATED — old store icon pipeline. Use finalize_kirarota_branding.py."""
from pathlib import Path
import sys

print(
    "WARNING: tool/integrate_store_branding.py is deprecated.",
    file=sys.stderr,
)
print("Redirecting to tool/finalize_kirarota_branding.py", file=sys.stderr)
sys.path.insert(0, str(Path(__file__).resolve().parent))
from finalize_kirarota_branding import main

if __name__ == "__main__":
    main()
