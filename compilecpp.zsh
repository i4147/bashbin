#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
set -euo pipefail
if [[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
	exit 1
fi
SRC="$1"
shift || true
if [[ ! -f "$SRC" ]]; then
	echo "error: source file not found: $SRC" >&2
	exit 1
fi
CC="${CC:-clang}"
CXX="${CXX:-clang++}"
STD="${STD:-c++17}"
OPT="${OPT:--O2}"
STRIP="${STRIP:-strip}"
EXTRA_CFLAGS="${EXTRA_CFLAGS:-}"
EXTRA_CXXFLAGS="${EXTRA_CXXFLAGS:-}"
EXTRA_LDFLAGS="${EXTRA_LDFLAGS:-}"
# ---------- detect language ----------
ext="${SRC##*.}"
case "$ext" in
c | C) LANG_KIND="c" ;;
cc | cpp | cxx | c++ | hpp | hxx | hh) LANG_KIND="cxx" ;;
*)
	echo "error: unknown source extension: .$ext" >&2
	echo "       expected .c, .cc, .cpp, .cxx, .c++" >&2
	exit 1
	;;
esac
# ---------- output name ----------
if [[ $# -ge 1 ]]; then
	OUT="$1"
else
	OUT="$(basename "$SRC")"
	OUT="${OUT%.*}"
fi
# ---------- build ----------
if [[ "$LANG_KIND" == "cxx" ]]; then
	COMPILER="$CXX"
	# shellcheck disable=SC2206
	FLAGS=(-std="$STD" $OPT -pthread $EXTRA_CXXFLAGS)
else
	COMPILER="$CC"
	# shellcheck disable=SC2206
	FLAGS=($OPT -pthread $EXTRA_CFLAGS)
fi
echo ">> $COMPILER ${FLAGS[*]} $SRC -o $OUT ${EXTRA_LDFLAGS:-}"
# shellcheck disable=SC2086
"$COMPILER" "${FLAGS[@]}" "$SRC" -o "$OUT" $EXTRA_LDFLAGS
# ---------- strip ----------
if command -v "$STRIP" >/dev/null 2>&1; then
	before=$(stat -c%s "$OUT" 2>/dev/null || echo 0)
	"$STRIP" "$OUT"
	after=$(stat -c%s "$OUT" 2>/dev/null || echo 0)
	printf '>> stripped %s: %s -> %s bytes\n' "$OUT" "$before" "$after"
else
	echo ">> strip not found, skipping" >&2
fi
echo ">> built: $OUT"
