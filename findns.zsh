#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
script_dir=$(dirname "$0")
script_dir=$(readlink -f "$script_dir")
. "$script_dir"/supprt/fslver
Usage() {
	ProgName=$(basename "$0")
	echo "find NonStripped executables.
Usage: $ProgName [[-r] [-f] paths(s) ...]
If no path(s) specified then the PATH is searched."
	exit
}
if [ $# -eq "0" ]; then
	eval set -- $(. "$script_dir"/supprt/getffp)
	FPF="%p"
else
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
fi
find -H "$@" -type f -perm /111 ! -name "*$LF*" -printf "%i\t$FPF\n" |
	sort -u |
	sort -k1,1n |
	cut -f2- |
	tr '\n' '\0' |
	xargs -r0 file |
	sed -n 's/\(.*\):[^:]*executable.* not stripped*/\1/p' |
	if [ -p /proc/self/fd/1 ]; then
		cat
	else
		tr '\n' '\0' |
			xargs -r0 ls -Ulb -- |
			sort -b -k5,5n
	fi
