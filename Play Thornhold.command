#!/bin/sh
set -eu
cd -- "$(dirname -- "$0")"
if [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
    exec /Applications/Godot.app/Contents/MacOS/Godot --path "$PWD"
elif command -v godot >/dev/null 2>&1; then
    exec godot --path "$PWD"
elif command -v godot4 >/dev/null 2>&1; then
    exec godot4 --path "$PWD"
else
    printf '%s\n' 'Install Godot 4.4 or later, then open project.godot and press F5.'
    exit 1
fi
