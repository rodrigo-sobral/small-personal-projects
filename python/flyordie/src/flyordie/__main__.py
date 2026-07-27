"""Entry point for ``python -m flyordie`` and packaged builds.

The import is absolute on purpose: PyInstaller runs this file as a top-level
script with no parent package, so a relative import fails there.
"""

from flyordie.app import main

if __name__ == "__main__":
    main()
