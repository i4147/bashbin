#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
#
# 7z-max-compress.sh — compress a file with 7z at max compression,
# and delete the original only if compression succeeds.
#
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $(basename "$0") <file>" >&2
    exit 1
fi

src=$1

if [[ ! -f $src ]]; then
    echo "Error: '$src' is not a regular file" >&2
    exit 1
fi

if ! command -v 7z >/dev/null 2>&1; then
    echo "Error: '7z' not found in PATH (install p7zip-full)" >&2
    exit 1
fi

archive="${src}.7z"

if [[ -e $archive ]]; then
    echo "Error: archive '$archive' already exists" >&2
    exit 1
fi

# Split into directory + basename so the archive stores only the filename,
# not the full path, and so we can run 7z from the file's own directory.
dir=$(dirname -- "$src")
base=$(basename -- "$src")

# -t7z   : 7z container format
# -mx=9  : maximum compression level
if ( cd -- "$dir" && 7z a -t7z -mx=9 -- "$base.7z" "$base" ); then
    rm -f -- "$src"
    echo "OK: '$src' -> '$archive' (original removed)"
else
    echo "Error: 7z failed; original '$src' kept" >&2
    exit 1
fi
