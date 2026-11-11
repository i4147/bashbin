#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
set -euo pipefail

command -v pixz >/dev/null 2>&1 || {
	echo "Install pixz"
	exit 1
}
command -v parallel >/dev/null 2>&1 || {
	echo "Install GNU parallel"
	exit 1
}

CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
THREADS_PER_JOB=$((CORES / 2))
[[ $THREADS_PER_JOB -lt 1 ]] && THREADS_PER_JOB=1

compress_dir() {
	local dir="$1"
	local dir_name="${dir#./}"
	local archive="${dir_name}.tar.xz"
	local threads="$2"
	[[ -f "$archive" ]] && {
		echo "⏭️ Skip: $dir_name"
		return 0
	}
	echo "🔄 $dir_name"
	if tar -cf - -C "$dir_name" . 2>/dev/null | pixz -9 -t "$threads" >"$archive" 2>/dev/null; then
		if tar -tf "$archive" >/dev/null 2>&1; then
			rm -rf "$dir_name"
			echo "✅ $dir_name → $(du -h "$archive" | cut -f1)"
			return 0
		fi
	fi
	echo "❌ Failed: $dir_name"
	rm -f "$archive"
	return 1
}

# GNU parallel starts a fresh process for each directory, so dispatch back to
# this script instead of relying on Bash-only exported functions.
if [[ "${1:-}" == "worker-compress" ]]; then
	[[ $# -ge 3 ]] || exit 2
	compress_dir "$2" "$3"
	exit $?
fi

echo "🧠 Using $CORES cores, $THREADS_PER_JOB threads per archive"
find . -maxdepth 1 -mindepth 1 -type d ! -name ".*" -printf "%P\n" |
	parallel -j "$CORES" --bar --eta "$0" worker-compress {} "$THREADS_PER_JOB"
echo "✅ Complete!"
