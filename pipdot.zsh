#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
# pip_install_offline.sh — editable install with zero network access
set -euo pipefail
PKG_DIR="."
WHEEL_DIR="/sdcard/whl" # <-- default find-links path
VENV=""
PYTHON="${PYTHON:-python3}"
EXTRA_ARGS=()
usage() {
	cat <<EOF
Usage: $0 [options] [-- extra pip args]
Options:
  -d, --dir DIR        project dir containing pyproject.toml/setup.py  (default: .)
  -w, --wheels DIR     folder with pre-downloaded wheels/sdists       (default: /sdcard/whl)
  -v, --venv DIR       create & use a venv at DIR
  -p, --python BIN     python interpreter to use                      (default: python3)
  -h, --help           show this help
Everything after -- is passed straight to pip.
EOF
	exit "${1:-0}"
}
while [[ $# -gt 0 ]]; do
	case "$1" in
	-d | --dir)
		PKG_DIR="$2"
		shift 2
		;;
	-w | --wheels)
		WHEEL_DIR="$2"
		shift 2
		;;
	-v | --venv)
		VENV="$2"
		shift 2
		;;
	-p | --python)
		PYTHON="$2"
		shift 2
		;;
	-h | --help) usage 0 ;;
	--)
		shift
		EXTRA_ARGS=("$@")
		break
		;;
	*)
		echo "unknown option: $1" >&2
		usage 1
		;;
	esac
done
[[ -d "$WHEEL_DIR" ]] || {
	echo "error: wheels dir '$WHEEL_DIR' not found" >&2
	exit 1
}
[[ -f "$PKG_DIR/pyproject.toml" || -f "$PKG_DIR/setup.py" ]] ||
	{
		echo "error: no pyproject.toml/setup.py in '$PKG_DIR'" >&2
		exit 1
	}
# Resolve to absolute path *before* any cd
WHEEL_DIR="$(cd "$WHEEL_DIR" && pwd)"
PKG_DIR="$(cd "$PKG_DIR" && pwd)"
if [[ -n "$VENV" ]]; then
	if [[ ! -d "$VENV" ]]; then
		echo "==> creating venv at $VENV"
		"$PYTHON" -m venv "$VENV"
	fi
	# shellcheck disable=SC1091
	source "$VENV/bin/activate"
	PYTHON="python"
fi
echo "==> python : $($PYTHON -V)"
echo "==> pkg dir: $PKG_DIR"
echo "==> wheels : $WHEEL_DIR"
echo "==> offline mode: ON"
echo
cd "$PKG_DIR"
# Hard offline: no index, no network, only local wheels.
exec "$PYTHON" -m pip install \
	--no-index \
	--find-links="$WHEEL_DIR" \
	--no-build-isolation \
	--no-input \
	--disable-pip-version-check \
	-e . \
	"${EXTRA_ARGS[@]}"
