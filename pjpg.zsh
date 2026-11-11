#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
#
# Recursively optimize all JPEGs in the current directory (in place), in parallel.
#   - quality 70 (cap; only lowers quality, never raises)
#   - --strip-all (EXIF/IPTC/ICC/comments)
#   - skip write if optimized output would be larger (jpegoptim default; no -f)
#
# Usage: ./optimize-jpgs.sh [--dry-run] [-j N]
#
set -euo pipefail

QUALITY=70
DRY_RUN=0
JOBS="$(command -v nproc >/dev/null && nproc || sysctl -n hw.ncpu 2>/dev/null || echo 4)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1; shift ;;
    -j)           JOBS="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [-j N]"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

command -v jpegoptim >/dev/null 2>&1 || { echo "jpegoptim not found" >&2; exit 1; }

echo "CWD: $(pwd)"
echo "Quality: $QUALITY | strip-all | skip-if-larger | jobs: $JOBS | dry-run: $DRY_RUN"
echo "------------------------------------------------------------"

OPTS=(-m"${QUALITY}" --strip-all -q)
if [[ "$DRY_RUN" -eq 1 ]]; then
  OPTS+=(-t)
else
  OPTS+=(-o)
fi

# -print0 / xargs -0: safe with spaces, quotes, newlines in filenames.
# -P "$JOBS": run up to N jpegoptim processes concurrently.
# Each invocation gets one file, so progress/logging stays per-file.
find . -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) -print0 \
  | xargs -0 -n1 -P"$JOBS" jpegoptim "${OPTS[@]}"

echo "------------------------------------------------------------"
echo "Done."
