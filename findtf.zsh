#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
script_dir=$(dirname "$0")
script_dir=$(readlink -f "$script_dir")
. "$script_dir"/supprt/fslver
Usage() {
	ProgName=$(basename "$0")
	echo "find Temporary Files.
Usage: $ProgName [-c] [--age=days] [[-r] [-f] paths(s) ...]
If -c specified then a more thorough search is done for
(and only for) core files, and more information is printed about them.
If --age=days specified then the temporary files must be over that
number of \"days\" old before being reported.
For e.g. findtf -c --age=4 only reports core files over 4 days old.
If no path(s) specified then the current directory is assumed."
	exit
}
MIN_AGE=0
for arg; do
	case "$arg" in
	-h | --help | -help)
		Usage
		;;
	-v | --version)
		Version
		;;
	--age=*)
		days=$(echo $arg | cut -b7-)
		[ "$days" ] && MIN_AGE=$days
		;;
	-c)
		core_mode="yes"
		;;
	*)
		argsToPassOn="$argsToPassOn $(shell_quote "$arg")"
		;;
	esac
done
if [ "$MIN_AGE" != "0" ]; then
	FIND_AGE="-mtime +$MIN_AGE"
fi
if [ "$force_full" = "yes" ]; then
	. "$script_dir"/supprt/getfpf -f "$argsToPassOn"
else
	. "$script_dir"/supprt/getfpf "$argsToPassOn"
fi
if [ "$core_mode" = "yes" ]; then
	find -H "$@" -type f -name "*core*" $FIND_AGE ! -name "*$LF*" \
		-printf "%p\n" |
		grep -E "/core$|\.core$|/core\.[0-9]+$" |
		xargs -r file |
		grep -F "core file " |
		if [ -p /proc/self/fd/1 ]; then
			cut -f1 -d:
		else
			cat
		fi
	exit
fi
tmpFiles="core dead.letter '*~' ',*' '*.v' tmp junk '\#*' \
'.emacs_[0-9]*' '*.[Bb][Aa][Kk]' '*.swp' '*.pure'"
Names=
for name in $tmpFiles; do
	[ -n "$Names" ] && Names="$Names -o "
	Names="${Names}-name $name"
done
Names="\( $Names \)"
eval find -H '"$@"' -type f $Names $FIND_AGE -printf "$FPF'\0'" |
	sort -zu |
	tr '\0' '\n'
