"""Where the app keeps player data and logs.

Run from a source checkout, everything stays next to the working directory as
before.  A packaged build has no writable working directory (macOS launches
bundles from ``/``), so it uses the per-user data directory instead.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

APP_DIRECTORY_NAME = "FlyOrDie"


def is_frozen() -> bool:
    """True when running from a PyInstaller build."""
    return bool(getattr(sys, "frozen", False))


def data_directory() -> Path:
    """Return the writable base directory for player data and logs."""
    if not is_frozen():
        return Path.cwd()
    if sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support" / APP_DIRECTORY_NAME
    elif sys.platform == "win32":
        base = Path(os.environ.get("APPDATA") or Path.home()) / APP_DIRECTORY_NAME
    else:
        base = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share") / "flyordie"
    base.mkdir(parents=True, exist_ok=True)
    return base
