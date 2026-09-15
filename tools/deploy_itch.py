#!/usr/bin/env python3
"""Build Thornhold's HTML5 release and deploy it to itch.io using Butler."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

from build_web import VERSION as GODOT_VERSION, WEB_FILES

ROOT = Path(__file__).resolve().parents[1]
BUTLER_VERSION = "15.31.0"
# SHA-256 of the pinned archives downloaded from the official broth service.
BUTLER_ARCHIVES = {
    "darwin-universal": "cc2204a7499c84e0fd389e12b34d01344a02a799250183bb86f71e510034db47",
    "linux-amd64": "4f2a3f22b12f870923504d4b6935535cad377b45859f5fe9419e3adc0611a48c",
    "linux-arm64": "2ffd4071dfa715024eedd2b4ac7406c1c7802452214d89a48496adb9c171b737",
    "windows-amd64": "92e42f011db049128583ac88258d3309d00c69018d2a48b378c7eb5709d9efde",
}


def find_butler(override):
    if override:
        executable = shutil.which(override)
        if not executable:
            raise RuntimeError("The --butler / BUTLER_BIN executable could not be found")
        return str(Path(executable).resolve())
    installed = shutil.which("butler")
    if installed:
        return str(Path(installed).resolve())

    system = platform.system().lower()
    machine = platform.machine().lower()
    arch = {"x86_64": "amd64", "amd64": "amd64", "aarch64": "arm64", "arm64": "arm64"}.get(machine)
    channel = "darwin-universal" if system == "darwin" and arch else f"{system}-{arch}"
    if channel not in BUTLER_ARCHIVES:
        raise RuntimeError(f"No bundled Butler installer for {system}/{machine}; set BUTLER_BIN")
    cache = ROOT / ".tools" / f"butler-{BUTLER_VERSION}" / channel
    cache.mkdir(parents=True, exist_ok=True)
    (ROOT / ".tools/.gdignore").touch()
    archive = cache / "butler.zip"
    if not archive.exists():
        url = f"https://broth.itch.zone/butler/{channel}/{BUTLER_VERSION}/archive/default"
        print(f"Downloading official Butler {BUTLER_VERSION} ({channel})...", flush=True)
        partial = archive.with_suffix(".download")
        subprocess.run(["curl", "--fail", "--location", "--silent", "--show-error", "--retry", "2",
                        url, "--output", str(partial)], check=True)
        partial.replace(archive)
    with archive.open("rb") as stream:
        if hashlib.file_digest(stream, "sha256").hexdigest() != BUTLER_ARCHIVES[channel]:
            raise RuntimeError(f"Butler archive checksum mismatch; remove {archive} and retry")
    name = "butler.exe" if system == "windows" else "butler"
    # push only needs the executable. Reading one known entry avoids extracting paths.
    with zipfile.ZipFile(archive) as bundle:
        binary = bundle.read(name)
    executable = cache / name
    if not executable.is_file() or executable.read_bytes() != binary:
        executable.write_bytes(binary)
    executable.chmod(0o755)
    return str(executable)


def stage_release():
    source = ROOT / "builds/web"
    manifest = json.loads((source / "build-manifest.json").read_text())
    if manifest.get("godot") != GODOT_VERSION or manifest.get("thread_support") is not False:
        raise RuntimeError("Rebuild with tools/build_web.py: expected the pinned, single-threaded web export")
    output = ROOT / "builds/itch"
    archive = ROOT / "builds/thornhold-itch.zip"
    with tempfile.TemporaryDirectory(prefix="itch-stage-", dir=source.parent) as temporary:
        staged = Path(temporary) / "release"
        staged.mkdir()
        for name in WEB_FILES:
            source_file = source / name
            if source_file.is_symlink():
                raise RuntimeError(f"Release files must not be symlinks: {name}")
            data = source_file.read_bytes()
            expected = manifest.get("files", {}).get(name, {})
            if len(data) != expected.get("bytes") or hashlib.sha256(data).hexdigest() != expected.get("sha256"):
                raise RuntimeError(f"Release checksum mismatch for {name}; rebuild before deploying")
            if not data or (name == "index.pck" and len(data) < 500_000):
                raise RuntimeError(f"Incomplete game export: {name}")
            (staged / name).write_bytes(data)
        # Stage only runtime files; the web folder may also contain hosting config or logs.
        if output.is_symlink():
            raise RuntimeError(f"Refusing to replace a symlink: {output}")
        if output.exists():
            shutil.rmtree(output)
        staged.replace(output)
    partial = archive.with_suffix(".zip.tmp")
    with zipfile.ZipFile(partial, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for name in WEB_FILES:
            bundle.write(output / name, name)
    partial.replace(archive)
    print(f"Ready: {archive} ({archive.stat().st_size / 1_000_000:.1f} MB)", flush=True)
    return output


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", default=os.environ.get("ITCH_TARGET"), help="itch.io username/game (or ITCH_TARGET)")
    parser.add_argument("--channel", default=os.environ.get("ITCH_CHANNEL", "html5"), help="Upload channel (default: html5)")
    parser.add_argument("--version", default=os.environ.get("ITCH_VERSION"), help="Release label passed to Butler --userversion")
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN"), help="Godot executable")
    parser.add_argument("--butler", default=os.environ.get("BUTLER_BIN"), help="Butler executable; otherwise found or installed locally")
    parser.add_argument("--skip-build", action="store_true", help="Use the existing export after checking its manifest")
    parser.add_argument("--non-interactive", action="store_true", help="Require BUTLER_API_KEY (also automatic when CI=true)")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="Build and list the upload with Butler; no authentication or upload")
    mode.add_argument("--login", action="store_true", help="Install/find Butler and log in once, without building or uploading")
    args = parser.parse_args(argv)
    ci = os.environ.get("CI", "").lower() not in ("", "0", "false")
    non_interactive = args.non_interactive or ci
    if args.login:
        if non_interactive:
            parser.error("Use a BUTLER_API_KEY secret in CI; --login is for a local interactive terminal")
        subprocess.run([find_butler(args.butler), "login"], check=True)
        return
    if not args.target or not re.fullmatch(r"[a-z0-9][a-z0-9_-]*/[a-z0-9][a-z0-9_-]*", args.target):
        parser.error("Set ITCH_TARGET or --target to username/game, e.g. your-name/thornhold")
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", args.channel):
        parser.error("Use a lowercase channel, e.g. html5 or html5-beta")
    if non_interactive and not args.dry_run and not os.environ.get("BUTLER_API_KEY"):
        parser.error("Set BUTLER_API_KEY as a CI secret before uploading")

    if not args.skip_build:
        command = [sys.executable, str(ROOT / "tools/build_web.py")]
        if args.godot:
            command.extend(["--godot", args.godot])
        subprocess.run(command, cwd=ROOT, check=True)
    release = stage_release()
    butler = find_butler(args.butler)
    destination = f"{args.target}:{args.channel}"
    command = [butler, "push", str(release), destination, "--if-changed"]
    if args.version:
        command.append(f"--userversion={args.version}")
    if args.dry_run:
        command.append("--dry-run")
    print(f"{'Dry run for' if args.dry_run else 'Uploading to'} {destination}", flush=True)
    # Butler inherits BUTLER_API_KEY, or uses its normal local login. Never put keys in arguments.
    subprocess.run(command, cwd=ROOT, check=True)
    if args.dry_run:
        print("Dry run complete. Nothing was uploaded.")
    else:
        print(f"Butler push completed: https://{args.target.split('/')[0]}.itch.io/{args.target.split('/')[1]}")
        print("First upload: set Kind to HTML and mark this upload as playable in the browser on itch.io.")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(f"Deployment stopped: {Path(error.cmd[0]).name} exited with status {error.returncode}", file=sys.stderr)
        sys.exit(error.returncode if error.returncode > 0 else 1)
    except (OSError, RuntimeError, ValueError, KeyError, zipfile.BadZipFile) as error:
        print(f"Deployment stopped: {error}", file=sys.stderr)
        sys.exit(1)
