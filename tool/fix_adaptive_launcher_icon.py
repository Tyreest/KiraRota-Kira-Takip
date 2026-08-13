# -*- coding: utf-8 -*-
"""Deprecated: use tool/finalize_kirarota_branding.py"""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from finalize_kirarota_branding import main

if __name__ == "__main__":
    main()
