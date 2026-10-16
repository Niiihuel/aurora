#!/usr/bin/env bash
# Compile every *.frag under a shader directory to *.frag.qsb.
#
#   scripts/shaders.sh [dir]          # default: shell/shaders
#
# Uses $QSB, or qsb from PATH (nix develop provides it). The .qsb files are
# build output: git ignores them and the Nix package regenerates them.
set -euo pipefail

dir="${1:-shell/shaders}"
qsb="${QSB:-qsb}"

shopt -s nullglob
frags=("$dir"/*.frag)
if [ ${#frags[@]} -eq 0 ]; then
    echo "no shaders in $dir" >&2
    exit 0
fi

for frag in "${frags[@]}"; do
    # Write next to the source and swap in atomically: a live shell
    # hot-reloads on change and must never see a half-written file.
    "$qsb" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$frag.qsb.tmp" "$frag"
    mv "$frag.qsb.tmp" "$frag.qsb"
    echo "compiled $frag"
done
