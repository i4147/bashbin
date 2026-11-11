#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
script_dir=$(dirname "$0")
script_dir=$(readlink -f "$script_dir")
. "$script_dir"/supprt/fslver
Usage() {
	ProgName=$(basename "$0")
	echo "find Redundant whiteSpace.
Usage: $ProgName [-w] [-t[#]] [-c] [[-r] [-f] paths(s) ...]
-w enables mode to report whitespace at the end of lines.
This is the default mode if none specified.
-t enables mode to report erroneous mixing of indenting
spaces and tabs (on a single line).
If a number is passed to -t it sets the width of the tabs,
which allows for more thorough checking.
If -c specified then the number of lines in each file,
with problematic whitespace is reported, in addition
to the file names. Note this will take longer.
If --view specified then the erroneous whitespace found
is highlighted using vim.
If no path(s) specified then the current directory is assumed."
	exit
}
eol='[ 	]+[
]*$'
for arg; do
	case "$arg" in
	-c)
		count="yes"
		;;
	--view)
		view="yes"
		;;
	-w)
		eol_specified="yes"
		;;
	-t*)
		ts=$(echo $arg | tr -cd '[:digit:]' | sed 's/^0*//;s/.*\(..\)/\1/')
		[ -z "$ts" ] && ts=8
		at_start='^[ 	]*'
		tabs="$at_start( 	|	 {$ts,})"
		;;
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
if [ -z "$eol_specified" ] && [ "$tabs" ]; then
	re="$tabs"
elif [ "$tabs" ]; then
	re="$tabs|$eol"
else
	re="$eol"
fi
. "$script_dir"/supprt/getfpf "$argsToPassOn"
find -H "$@" -type f -size +0c ! -name "*$LF*" -printf "$FPF\0" |
	sort -zu |
	xargs -r0 file |
	sed -n 's/\(.*\):[^:]*text.*/\1/p' |
	tr '\n' '\0' |
	if [ "$view" = "yes" ]; then
		xargs -r0 grep -nE "$re" |
			"$script_dir"/supprt/rmlint/view_ws.sh -
	elif [ "$count" = "yes" ]; then
		xargs -r0 grep -Ec "$re" |
			grep -vE "(:0$|^0$)" |
			sort -k2,2nr -t:
	else
		xargs -r0 grep -El "$re"
	fi
