# PyInstaller build spec: run through scripts/build.sh, not directly.
import sys
from pathlib import Path

PROJECT = Path(SPECPATH)
ASSETS = PROJECT / "assets"

if sys.platform == "darwin":
    icon = str(ASSETS / "flyordie.icns")
elif sys.platform == "win32":
    icon = str(ASSETS / "flyordie.ico")
else:
    icon = str(ASSETS / "flyordie.png")

analysis = Analysis(
    [str(PROJECT / "src" / "flyordie" / "__main__.py")],
    pathex=[str(PROJECT / "src")],
    # The runtime icon lookup expects the file beside the package.
    datas=[(str(ASSETS / "favicon.ico"), "flyordie/assets")],
    hiddenimports=["PIL._tkinter_finder"],
    excludes=["pytest", "ruff", "watchfiles"],
    noarchive=False,
)
pyz = PYZ(analysis.pure)

exe = EXE(
    pyz,
    analysis.scripts,
    [],
    exclude_binaries=True,
    name="FlyOrDie",
    console=False,
    icon=icon,
)
collect = COLLECT(
    exe,
    analysis.binaries,
    analysis.datas,
    name="FlyOrDie",
)

if sys.platform == "darwin":
    app = BUNDLE(
        collect,
        name="FlyOrDie.app",
        icon=icon,
        bundle_identifier="dev.rodrigo.flyordie",
        info_plist={
            "CFBundleShortVersionString": "1.0.0",
            "CFBundleVersion": "1.0.0",
            "NSHighResolutionCapable": True,
            "LSApplicationCategoryType": "public.app-category.utilities",
        },
    )
