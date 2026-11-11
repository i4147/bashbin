#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
script_dir=$(dirname "$0")
script_dir=$(readlink -f "$script_dir")
. "$script_dir"/supprt/fslver
Usage() {
	ProgName=$(basename "$0")
	echo "find names with invalid UTF8 encoding.
Usage: $ProgName [[-r] [-f] paths(s) ...]
If no path(s) specified then the current directory is assumed."
	exit
}
for arg; do
	case "$arg" in
	-h | --help | -help)
		Usage
		;;
	-v | --version)
		Version
		;;
	*)
		argsToPassOn="$argsToPassOn $(shell_quote "$arg")"
		;;
	esac
done
. "$script_dir"/supprt/getfpf "$argsToPassOn"
find -H "$@" -printf "$FPF\0" |
	sort -zu |
	tr '\n\0' '\1\n' |
	LANG=C grep -E '[^ -~]' |
	while read; do
		name="$REPLY"
		echo "$name" | iconv --from=utf8 --to=utf8 >/dev/null 2>&1 || echo "$name"
	done |
	tr '\n\1' '\0\n' |
	if [ ! -p /proc/self/fd/1 ]; then
		xargs -r0 ls -b1Ud --color=auto --
	else
		cat
	fi
