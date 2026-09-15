# Deploy Thornhold on Vercel

This directory is the complete release build. It requires no server, database,
environment variables, npm dependencies, or Godot installation to deploy.

## Release

Unzip `thornhold-vercel.zip` into an empty folder, open a terminal there, then run:

```sh
npx vercel --prod
```

Sign in and create or choose your Vercel project when prompted. Use the **Other**
framework preset. `vercel.json` sets the output directory to `.` and disables the
install and build commands. Keep all exported files together with their original
names. The command prints your production URL when deployment finishes.

For a preview deployment, omit `--prod`. For Git-based deployment, commit the
contents of this build directory to a repository and import that repository into
Vercel with the same settings. The Godot source project needs an export before
it can be served; Vercel does not compile the source in this package.

## Local preview

```sh
python3 -m http.server 8080
```

Visit `http://localhost:8080`. Opening `index.html` directly from disk will not
work because the browser must fetch the WebAssembly runtime and game pack.

## Playing

Use a desktop browser with WebGL 2 and WebAssembly, a keyboard, and a mouse.
Click **Enter the labyrinth** to start, enable sound, and capture the pointer.
WASD moves, the mouse looks, left click attacks, right click blocks, Shift sprints,
Space jumps, B opens the armory, M opens the map, and Esc pauses/releases the
pointer. Touch controls are not included. Best times use browser-local storage.

## Hosting details

- Godot 4.7.2 release export, Compatibility renderer, threads disabled.
- No cross-origin isolation headers or service worker are required.
- Explicit MIME types for `.wasm` and `.pck`; files revalidate on updates so a new
  game pack is not mixed with a stale runtime or HTML file.
- `build-manifest.json` records file sizes and SHA-256 checksums.

References: [Godot web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html),
[Vercel configuration](https://vercel.com/docs/project-configuration/vercel-json),
[Vercel deployment CLI](https://vercel.com/docs/cli/deploy).
