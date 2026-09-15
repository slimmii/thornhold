#!/usr/bin/env python3
"""Export and package the static Godot game for Vercel; no deployment occurs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.7.2"
ARCHIVE_SHA256 = "f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011"
TEMPLATE_SHA256 = "d3ee2f08cef0cf3cf6678a6355a92a8db48ccdd35cbd2e8bfd5f0e8a0b4032a0"
CACHE = ROOT / ".tools" / f"godot-{VERSION}"
TEMPLATE = CACHE / "web_nothreads_release.zip"
OUTPUT = ROOT / "builds/web"
WEB_FILES = (
    "index.html", "index.js", "index.wasm", "index.pck", "index.png",
    "index.icon.png", "index.apple-touch-icon.png",
    "index.audio.worklet.js", "index.audio.position.worklet.js",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN"))
    parser.add_argument("--package-only", action="store_true", help="Package an existing export without rebuilding it")
    args = parser.parse_args()
    if not args.package_only:
        godot = args.godot or shutil.which("godot") or shutil.which("godot4")
        mac = Path("/Applications/Godot.app/Contents/MacOS/Godot")
        if not godot and mac.exists():
            godot = str(mac)
        if not godot:
            parser.error("Install Godot 4.7.2 or pass --godot /path/to/godot")
        version = subprocess.check_output([godot, "--version"], text=True).strip()
        if not version.startswith(VERSION + ".stable"):
            parser.error(f"Expected Godot {VERSION}.stable, found {version}; templates must match the engine")
        CACHE.mkdir(parents=True, exist_ok=True)
        (CACHE.parent / ".gdignore").touch()
        if not TEMPLATE.exists():
            archive = CACHE / "export_templates.tpz"
            if not archive.exists():
                url = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz"
                print("Downloading official Godot export templates (first build only)...", flush=True)
                partial = archive.with_suffix(".download")
                subprocess.run(["curl", "-L", "--fail", "--show-error", "--retry", "2", url, "-o", str(partial)], check=True)
                partial.replace(archive)
            with archive.open("rb") as downloaded:
                if hashlib.file_digest(downloaded, "sha256").hexdigest() != ARCHIVE_SHA256:
                    raise RuntimeError("Export archive does not match the official release checksum")
            with zipfile.ZipFile(archive) as bundle:
                TEMPLATE.write_bytes(bundle.read("templates/web_nothreads_release.zip"))
            archive.unlink()
        if hashlib.sha256(TEMPLATE.read_bytes()).hexdigest() != TEMPLATE_SHA256:
            raise RuntimeError("Web template does not match the pinned Godot release")
        with zipfile.ZipFile(TEMPLATE) as template:
            if template.testzip():
                raise RuntimeError("The downloaded web template failed its integrity check")
        OUTPUT.mkdir(parents=True, exist_ok=True)
        (OUTPUT.parent / ".gdignore").touch()
        subprocess.run([godot, "--headless", "--editor", "--path", str(ROOT), "--import", "--log-file", str(CACHE / "import.log")], check=True)
        subprocess.run([godot, "--headless", "--path", str(ROOT), "--export-release", "Web", str(OUTPUT / "index.html"), "--log-file", str(CACHE / "export.log")], check=True)

    for name in WEB_FILES:
        if not (OUTPUT / name).is_file():
            raise RuntimeError(f"Missing web export file: {name}")
    # A scene-only export can silently omit scripts referenced by global class names.
    if (OUTPUT / "index.pck").stat().st_size < 500_000:
        raise RuntimeError("Game pack is unexpectedly small; verify models and global scripts are included")
    shutil.copy2(ROOT / "web/vercel.json", OUTPUT / "vercel.json")
    shutil.copy2(ROOT / "web/DEPLOY.md", OUTPUT / "DEPLOY.md")
    files = [OUTPUT / name for name in (*WEB_FILES, "vercel.json", "DEPLOY.md")]
    manifest = {"godot": VERSION, "thread_support": False, "files": {p.name: {"bytes": p.stat().st_size, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in files}}
    (OUTPUT / "build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    archive = ROOT / "builds/thornhold-vercel.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for path in [*files, OUTPUT / "build-manifest.json"]:
            bundle.write(path, path.name)
    print(f"Ready: {archive} ({archive.stat().st_size / 1_000_000:.1f} MB)")
    print(f"Deploy: cd {OUTPUT} && npx vercel --prod")


if __name__ == "__main__":
    main()
