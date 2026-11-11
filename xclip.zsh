#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
# xclip-compatible wrapper for Termux using termux-api
set -euo pipefail
# Defaults
selection="primary" # accepted for compatibility, ignored
mode="in"           # "in" = copy to clipboard, "out" = paste
infile=""
loops=0
# Parse args
while [ $# -gt 0 ]; do
	case "$1" in
	-selection | -sel)
		selection="$2"
		shift 2
		;;
	-o | -out)
		mode="out"
		shift
		;;
	-i | -in)
		mode="in"
		shift
		;;
	-l | -loops)
		loops="$2"
		shift 2
		;;
	-f | -filter)
		shift
		;; # no-op, termux handles this fine
	-t | -target)
		shift 2
		;; # MIME type, ignored
	-d | -display)
		shift 2
		;; # X display, ignored
	-verbose)
		shift
		;;
	-h | --help)
		echo "Usage: xclip [-selection clipboard|primary] [-o|-i] [file]"
		exit 0
		;;
	-*)
		echo "xclip: unknown option: $1" >&2
		exit 1
		;;
	*)
		infile="$1"
		shift
		;;
	esac
done
if [ "$mode" = "out" ]; then
	# Paste: clipboard -> stdout
	termux-clipboard-get
else
	# Copy: stdin or file -> clipboard
	if [ -n "$infile" ]; then
		if [ ! -r "$infile" ]; then
			echo "xclip: cannot read '$infile'" >&2
			exit 1
		fi
		termux-clipboard-set <"$infile"
	else
		# Read stdin fully, then set clipboard
		data="$(cat)"
		printf '%s' "$data" | termux-clipboard-set
	fi
fi
