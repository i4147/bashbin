#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
script_dir=$(dirname "$0")
script_dir=$(readlink -f "$script_dir")
. "$script_dir"/supprt/fslver
Usage() {
	ProgName=$(basename "$0")
	echo "find Name (directory or file) Lint.
Usage: $ProgName [-1] [-2] [-3] [-p] [[-r] [-f] paths(s) ...]
These options are mutually exclusive (i.e. only the last one takes effect).
-1 is least checking, -3 is most. The default is 2.
-p is most stringent and applies POSIX.1 filename portability testing.
I.E. characters are limited to [A-Za-z0-9_.-] and max name length = 14 and
max path length = 255.
If no path(s) specified then the current directory is assumed."
	exit
}
level=2
MaxNameLen=129
MaxPathLen=2049
for arg; do
	case "$arg" in
	-1)
		level="1"
		MaxNameLen=256
		MaxPathLen=4097
		;;
	-2)
		:
		;;
	-3)
		level="3"
		MaxNameLen=65
		MaxPathLen=1025
		;;
	-p)
		level="p"
		MaxNameLen=15
		MaxPathLen=256
		;;
	-h | --help | -help)
		Usage
		;;
	-v | --version)
		Version
		;;
	*)
		if [ -e "$arg" ] && ! echo "$arg" | grep -qF /; then
			arg="./$arg"
		fi
		argsToPassOn="$argsToPassOn $(shell_quote "$arg")"
		;;
	esac
done
if [ "$level" != "p" ]; then
	unset LC_CTYPE
fi
expressionsp="(.*/[^/]{$MaxNameLen,}$)"
expressions1="$expressionsp|( +$)"
expressions1="$expressions1|(.*/ [^/]*$)"
expressions1="$expressions1|(.*/[^/]*[ ]{2,}[^/]*$)"
expressions1="$expressions1|(.*/-[^/]*$)"
expressions1="$expressions1|(.*/[^/]* -[^/]*$)"
expressions2="$expressions1|(.*/[^/]*\{[^/]*,[^/]*\}[^/]*$)"
expressions2="$expressions2|(.*/[^/]*\[[^/]+\][^/]*$)"
expressions2="$expressions2|(.*/~[^/]*$)"
expressions3="$expressions2|(.*/[^/]*[.]{2,}[^/]*$)"
expressions3="$expressions3|(.+[.]$)"
charactersp="[:alnum:]_./"
characters3="$charactersp,~+"
characters2="$characters3@#!=[{}:;'<>%& "
characters1="$characters2()\"$|\\"
eval expressions=\$expressions$level
eval characters=\$characters$level
. "$script_dir"/supprt/getfpf -f "$argsToPassOn"
find -H "$@" -printf "$FPF\0" |
	sort -zu |
	tr '\n\0' '\1\n' |
	grep -E "$expressions|(.*/[^/]*[^]$characters-]+[^/]*$)" |
	tr '\n\1' '\0\n' |
	if [ ! -p /proc/self/fd/1 ]; then
		xargs -r0 ls -b1Ud --color=auto --
	else
		cat
	fi
