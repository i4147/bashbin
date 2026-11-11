#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
#
# htmlmin.zsh — minify an HTML file in place using html-minifier-terser.
#
# Usage:
#   ./htmlmin.zsh file.html            # minify in place (creates file.html.bak)
#   ./htmlmin.zsh -n file.html         # no backup
#   ./htmlmin.zsh -o out.html in.html  # write to another file (no inplace)
#   ./htmlmin.zsh -h                   # help
#
set -euo pipefail

PROG="$(basename -- "$0")"
BACKUP=1
OUTPUT=""

usage() {
	cat <<EOF
Usage: $PROG [options] <file.html>

Minify an HTML file (inline <style> and <script> are minified too)
using html-minifier-terser, which is fetched via npx if not installed.

Options:
  -n, --no-backup     Do not create a .bak backup when writing in place.
  -o, --output FILE   Write minified output to FILE (input file untouched).
  -h, --help          Show this help and exit.

Examples:
  $PROG index.html
  $PROG --no-backup index.html
  $PROG -o dist/index.min.html index.html
EOF
}

# ---------- parse args ----------
while [[ $# -gt 0 ]]; do
	case "$1" in
	-n | --no-backup)
		BACKUP=0
		shift
		;;
	-o | --output)
		[[ $# -ge 2 ]] || {
			echo "$PROG: -o requires an argument" >&2
			exit 2
		}
		OUTPUT="$2"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	--)
		shift
		break
		;;
	-*)
		echo "$PROG: unknown option: $1" >&2
		usage >&2
		exit 2
		;;
	*) break ;;
	esac
done

if [[ $# -ne 1 ]]; then
	echo "$PROG: expected exactly one input file" >&2
	usage >&2
	exit 2
fi

INPUT="$1"

# ---------- sanity checks ----------
[[ -f "$INPUT" ]] || {
	echo "$PROG: no such file: $INPUT" >&2
	exit 1
}
[[ -r "$INPUT" ]] || {
	echo "$PROG: cannot read: $INPUT" >&2
	exit 1
}

command -v node >/dev/null 2>&1 || {
	echo "$PROG: 'node' is required but not found in PATH" >&2
	exit 1
}

# npx ships with npm/node. If html-minifier-terser is already installed
# locally or globally, npx will just use it; otherwise it downloads it.
if ! command -v npx >/dev/null 2>&1; then
	echo "$PROG: 'npx' not found. Install Node.js (npm) first." >&2
	exit 1
fi

# ---------- figure out where to write ----------
INPLACE=1
if [[ -n "$OUTPUT" ]]; then
	INPLACE=0
	DEST="$OUTPUT"
	mkdir -p -- "$(dirname -- "$OUTPUT")"
else
	DEST="$INPUT"
fi

# Temp file in the destination's directory so `mv` is atomic (same FS).
DEST_DIR="$(dirname -- "$DEST")"
DEST_BASE="$(basename -- "$DEST")"
TMP="$(mktemp -- "${DEST_DIR}/.${DEST_BASE}.min.XXXXXX")"
trap 'rm -f -- "$TMP"' EXIT

# ---------- minify ----------
# Notes on flags:
#   --minify-css / --minify-js  -> also minify inline <style> and <script>.
#   --collapse-whitespace etc.  -> conservative HTML-side reductions.
#   --keep-closing-slash        -> keep /> on void elements (harmless, safer).
HTMLMIN_ARGS=(
	--collapse-whitespace
	--remove-comments
	--remove-redundant-attributes
	--remove-script-type-attributes
	--remove-style-link-type-attributes
	--remove-empty-attributes
	--use-short-doctype
	--minify-css true
	--minify-js true
)

echo "$PROG: minifying '$INPUT' -> '$DEST'" >&2

if ! npx --yes html-minifier-terser "${HTMLMIN_ARGS[@]}" -o "$TMP" -- "$INPUT"; then
	echo "$PROG: html-minifier-terser failed" >&2
	exit 1
fi

# Guard: refuse to replace if output is suspiciously empty.
if [[ ! -s "$TMP" ]]; then
	echo "$PROG: minifier produced an empty file; aborting" >&2
	exit 1
fi

# ---------- backup + atomic move ----------
if [[ $INPLACE -eq 1 && $BACKUP -eq 1 ]]; then
	cp -p -- "$INPUT" "${INPUT}.bak"
	echo "$PROG: backup written to '${INPUT}.bak'" >&2
fi

mv -f -- "$TMP" "$DEST"
trap - EXIT

# ---------- report ----------
if command -v stat >/dev/null 2>&1; then
	OLD=$(stat -c%s -- "$INPUT" 2>/dev/null || stat -f%z -- "$INPUT" 2>/dev/null || echo "?")
	NEW=$(stat -c%s -- "$DEST" 2>/dev/null || stat -f%z -- "$DEST" 2>/dev/null || echo "?")
	if [[ "$OLD" =~ ^[0-9]+$ && "$NEW" =~ ^[0-9]+$ && "$OLD" -gt 0 ]]; then
		PCT=$(awk -v o="$OLD" -v n="$NEW" 'BEGIN{printf "%.1f", (1-n/o)*100}')
		printf '%s: done. %s -> %s bytes (-%s%%)\n' "$PROG" "$OLD" "$NEW" "$PCT" >&2
	else
		echo "$PROG: done." >&2
	fi
fi
