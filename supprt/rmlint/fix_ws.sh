#!/data/data/com.termux/files/usr/bin/bash
set -e
usage() {
	prog=$(basename "$0")
	echo "Usage: $prog --eol|'' --indent-spaces|--indent-tabs|'' indent_width|'' filename" >&2
	exit 1
}
[ "$#" = "4" ] || usage
FILE="$4"
if [ ! -f "$FILE" ]; then
	echo "Error: '$FILE' is not a regular file" >&2
	exit 1
fi
cmp /dev/null /dev/null 2>/dev/null && CMP=cmp || CMP=false
TMP=${TMPDIR:-/tmp}
TMP="$TMP/fix_ws.$$"
trap 'rm -f "$TMP"' EXIT
if [ "$1" = "--eol" ]; then
	STRIP_EOL_SPACES="sed -e 's/[ 	]*$//'"
fi
if [ "$2" = "--indent-spaces" ]; then
	TAB_CONVERT="unexpand --first-only -t$3"
	TAB_CONVERT="$TAB_CONVERT | expand --initial -t$3"
elif [ "$2" = "--indent-tabs" ]; then
	TAB_CONVERT="unexpand --first-only -t$3"
fi
[ "$STRIP_EOL_SPACES" ] && COMMAND="$STRIP_EOL_SPACES"
if [ "$TAB_CONVERT" ]; then
	[ "$COMMAND" ] && COMMAND="$COMMAND | "
	COMMAND="$COMMAND$TAB_CONVERT"
fi
[ "$COMMAND" ] || usage
eval "$COMMAND" <"$FILE" >"$TMP" ||
	{
		echo "Error[$?]: $COMMAND < '$FILE' > '$TMP'" >&2
		exit 1
	}
! $CMP -s "$TMP" "$FILE" && cp "$TMP" "$FILE"
