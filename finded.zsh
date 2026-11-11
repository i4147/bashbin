#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
script_dir=$(dirname "$0")
script_dir=$(readlink -f "$script_dir")
. "$script_dir"/supprt/fslver
Usage() {
	ProgName=$(basename "$0")
	echo "find Empty Directory branches.
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
	* | -r)
		test "$arg" = "-r" && recurse="false"
		argsToPassOn="$argsToPassOn $(shell_quote "$arg")"
		;;
	esac
done
. "$script_dir"/supprt/getfpf -f "$argsToPassOn"
if test "$recurse" = "false"; then
	find "$@" -empty -type d ! -name "*$LF*" -printf "$FPF\0" |
		sort -zu |
		if [ ! -p /proc/self/fd/1 ]; then
			xargs -r0 ls -b1Ud --
		else
			cat
		fi
	exit
fi
if printf "%s\n" "$@" | tr -s '/' | grep -q './$'; then
	echo "Error: trailing '/' in a parameter is not allowed" >&2
	exit 1
fi
(
	find "$@" -type d ! -name "*$LF*" -printf "$FPF\n" |
		sort -u
	find "$@" ! -type d ! -name "*$LF*" -printf "%h\n" |
		uniq |
		sed -n ':s; p;p; s#/\{0,\}[^/]\{1,\}$##; /./b s'
	find "$@" -maxdepth 0 ! -name "*$LF*" -printf "%h\n%h\n" |
		sed '/^\//!d' |
		sed -n ':s; p;p; s#/\{0,\}[^/]\{1,\}$##; /./b s'
) |
	sort | uniq -u |
	sed 'p; :s $!N; s/^\(.*\)\n\1\/.*/\1/; t s; D' |
	tr '\n' '\0' |
	if [ ! -p /proc/self/fd/1 ]; then
		xargs -r0 ls -b1Ud --
	else
		cat
	fi
