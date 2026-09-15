# Automatic itch.io deployment

Run from the source project with Python **3.11+**, curl, and **Godot 4.7.2**
installed. The script finds Godot on PATH or in `/Applications/Godot.app`;
`GODOT_BIN` / `--godot` can select another executable. Matching Godot export
templates are downloaded and cached on the first build (about 1.3 GB download).

## One-time setup

1. Create an itch.io project. For `https://your-name.itch.io/thornhold`, the
   deployment target is `your-name/thornhold`.
2. Log in locally:

   ```sh
   python3 tools/deploy_itch.py --login
   ```

   Butler opens its normal browser authentication flow. If Butler is not on PATH,
   the script downloads version **15.31.0** from the official broth service,
   verifies a pinned SHA-256 checksum, and caches it under `.tools/`. Automatic
   installation supports macOS Intel/Apple Silicon, Linux x64/ARM64, and Windows
   x64. Set `BUTLER_BIN` / `--butler` to use a specific installation.

## Build and deploy

```sh
python3 tools/deploy_itch.py --target your-name/thornhold --version 1.0.0
```

This exports the game, validates its checksums, stages only the nine runtime
files in `builds/itch/`, creates `builds/thornhold-itch.zip`, and calls:

```sh
butler push builds/itch your-name/thornhold:html5 --if-changed --userversion=1.0.0
```

Subsequent runs update the same channel. Identical builds are skipped, including
when only the version label changes. Omit `--version` to use itch.io's automatic
build number. Build, checksum, download, or upload failures return a nonzero exit
status so an automation runner can detect failure.

After the **first upload**, open **Edit game** on itch.io, set **Kind of project**
to **HTML**, and check **This file will be played in the browser** for the `html5`
upload. Save the page. Butler cannot set these browser-play settings. Choose
**Click to launch in fullscreen** for the game's keyboard and mouse controls;
leave mobile support off. Project visibility is managed on itch.io, and later
pushes can update the playable build immediately.

## Preview without uploading

```sh
python3 tools/deploy_itch.py --target your-name/thornhold --dry-run
```

This builds and packages normally, then runs Butler's `push --dry-run`. It lists
the upload without authenticating or sending a build. The initial tool/template
downloads still need internet access. Add `--skip-build` to use an existing
export; its runtime files must still match `build-manifest.json`.

The ZIP is also ready for manual upload, with `index.html` at its root.

## Unattended / CI use

Configure these variables in your automation runner:

| Variable | Value |
| --- | --- |
| `ITCH_TARGET` | Required `username/game` target |
| `BUTLER_API_KEY` | Secret from your Butler login / itch.io API-key settings |
| `ITCH_CHANNEL` | Optional; defaults to `html5` |
| `ITCH_VERSION` | Optional release tag, commit SHA, or build number |
| `GODOT_BIN` | Optional path to the Godot 4.7.2 executable |
| `BUTLER_BIN` | Optional path to an existing Butler executable |

Then call this from your release job after checking out the project and
installing Godot, Python, and curl:

```sh
python3 tools/deploy_itch.py --non-interactive
```

This is the complete build-and-deploy step; you do not need to run the exporter
separately. The script requires `BUTLER_API_KEY` when `CI=true` or
`--non-interactive` is set, so a missing secret fails before building or opening
a login browser. Store the key in the runner's secret store, not a source file
or command argument. The script passes it only through Butler's environment.
No CI provider or release trigger is configured by this script.

## Verification

```sh
python3 tests/itch_deploy_test.py
```

These tests use a recording Butler stub and isolated exports to check build
failure handling, CI authentication, version/channel arguments, dry runs,
checksum rejection, runtime-only staging, and upload exit codes. A real Butler
dry run validates the local release without publishing it.

The web release uses Godot's Compatibility renderer with threads disabled, so
itch.io does not need cross-origin isolation headers. It requires a desktop
browser with WebGL 2, WebAssembly, a keyboard, and a mouse.

References: [Butler installation](https://itch.io/docs/butler/installing.html),
[authentication](https://itch.io/docs/butler/login.html),
[pushing and HTML5 setup](https://itch.io/docs/butler/pushing.html),
[itch.io HTML5 games](https://itch.io/docs/creators/html5).
