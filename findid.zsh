#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
script_dir=$(dirname "$0")
script_dir=$(readlink -f "$script_dir")
. "$script_dir"/supprt/fslver
Usage() {
	ProgName=$(basename "$0")
	echo "find unused or bad file ids
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
reUsers="$(cut -f3 -d: /etc/passwd | tr '\n' '|')0"
reGroups="$(cut -f3 -d: /etc/group | tr '\n' '|')0"
find -H "$@" -printf "%U:%G:$FPF\0" |
	sort -zu |
	tr '\n\0' '\1\n' |
	grep -Ev "^($reUsers):($reGroups):" |
	cut -d: -f3- |
	tr '\n\1' '\0\n' |
	if [ -p /proc/self/fd/1 ]; then
		cat
	else
		xargs -r0 ls -lUdb --color=auto --
	fi
