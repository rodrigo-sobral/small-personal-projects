"""Application-wide, local-only logging configuration."""

from __future__ import annotations

import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path

LOG_FILE_NAME = "flyordie.log"


def configure_logging(log_directory: Path | None = None) -> Path:
    """Configure a bounded UTF-8 log file and return its path.

    The file defaults to the directory from which the program is started.  A
    rotating handler prevents routine diagnostic data from growing forever.
    Calling the function more than once is safe, which helps test runners and
    embedded launches.
    """
    directory = (log_directory or Path.cwd()).joinpath("logs")
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / LOG_FILE_NAME
    root = logging.getLogger()
    if getattr(root, "_flyordie_configured", False):
        return path

    handler = RotatingFileHandler(path, maxBytes=1_000_000, backupCount=3, encoding="utf-8")
    handler.setFormatter(
        logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s", "%Y-%m-%d %H:%M:%S")
    )
    root.setLevel(logging.INFO)
    root.addHandler(handler)
    root._flyordie_configured = True  # type: ignore[attr-defined]
    logging.getLogger(__name__).info("Logging started; writing to %s", path)
    return path


def clear_log() -> Path:
    """Truncate the active log while keeping the configured handler usable."""
    root = logging.getLogger()
    for handler in root.handlers:
        if isinstance(handler, RotatingFileHandler):
            handler.flush()
            with open(handler.baseFilename, "w", encoding="utf-8"):
                pass
            logging.getLogger(__name__).info("Log cleared")
            return Path(handler.baseFilename)
    path = Path.cwd().joinpath("logs") / LOG_FILE_NAME
    path.unlink(missing_ok=True)
    return path
