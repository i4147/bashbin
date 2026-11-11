#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
#
# build_wheels.zsh — recursively build wheels for every Python project
# under ROOT. For each project directory:
#   1. Skip if dist/*.whl already exists.
#   2. Try `setup.py bdist_wheel` (if setup.py exists).
#   3. Fall back to `python -m build -w` (if pyproject.toml exists).
# Builds run in parallel via xargs -P.
#
# Usage:
#   ./build_wheels.zsh [ROOT]         # default ROOT=.
#   JOBS=8 ./build_wheels.zsh .       # control parallelism
#   PYTHON=python3 ./build_wheels.zsh # pick interpreter
#
set -uo pipefail

ROOT="${1:-.}"
PYTHON="${PYTHON:-python}"
JOBS="${JOBS:-$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"

build_one() {
	local dir="$1"
	pushd "$dir" >/dev/null 2>&1 || {
		echo "[fail]   cannot cd into $dir"
		return 1
	}

	# Skip if a wheel already exists in dist/ using a portable file search.
	if find dist -maxdepth 1 -name '*.whl' -print -quit 2>/dev/null | grep -q .; then
		echo "[skip]   $dir (dist/*.whl present)"
		popd >/dev/null
		return 0
	fi

	# 1) setup.py first
	if [[ -f setup.py ]]; then
		echo "[setup]  $dir"
		if "$PYTHON" setup.py bdist_wheel; then
			popd >/dev/null
			return 0
		fi
		echo "[retry]  $dir (setup.py failed, falling back to pyproject.toml)"
	fi

	# 2) pyproject.toml fallback
	if [[ -f pyproject.toml ]]; then
		echo "[pyproj] $dir"
		if "$PYTHON" -m build -w; then
			popd >/dev/null
			return 0
		fi
		echo "[fail]   $dir (pyproject build failed)"
		popd >/dev/null
		return 1
	fi

	echo "[fail]   $dir (no setup.py or pyproject.toml)"
	popd >/dev/null
	return 1
}

export PYTHON

# A worker invocation runs the same Zsh script in a separate xargs process.
if [[ "${1:-}" == "worker-build" ]]; then
	[[ $# -ge 2 ]] || exit 2
	build_one "$2"
	exit $?
fi

# Collect every directory that contains either a setup.py or pyproject.toml.
# The (@f) expansion preserves each newline-delimited path as one array item.
dirs=( "${(@f)$(find "$ROOT" -type f \( -name setup.py -o -name pyproject.toml \) -printf '%h\n' 2>/dev/null | sort -u)}" )

if [[ ${#dirs[@]} -eq 0 ]]; then
	echo "No setup.py or pyproject.toml found under: $ROOT"
	exit 0
fi

echo "Found ${#dirs[@]} project director(ies) under '$ROOT' — running with JOBS=$JOBS"
echo "----------------------------------------------------------------------"

# Run workers in parallel without relying on Bash-only function export.
printf '%s\0' "${dirs[@]}" |
	xargs -0 -n1 -P "$JOBS" "$0" worker-build

echo "----------------------------------------------------------------------"
echo "Done."
