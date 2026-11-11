#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
script_dir=$(dirname "$0")
script_dir=$(readlink -f "$script_dir")
. "$script_dir"/supprt/fslver
Usage() {
	ProgName=$(basename "$0")
	echo "find \"Bad\" symbolic Links.
Usage: $ProgName [-d] [-s] [-l] [-s] [-n] [[-r] [-f] paths(s) ...]
These options are mutually exclusive (i.e. only the last one takes effect).
-d Dangling (or stale) links. This is the default mode
-s Suspect links (absolute links to paths within or below the link's directory)
-l all reLative links
-A all Absolute links
-n reduNdant info in links (/././. ///// /../ etc.)
If no path(s) specified, then the current directory is assumed.
e.g. find dangling links in "library directories":
findbl \$(getffl)"
	exit
}
mode="dangling"
ASC_01=$(printf "\001")
for arg; do
	case "$arg" in
	-d)
		mode="dangling"
		;;
	-s)
		mode="suspect"
		;;
	-A)
		mode="absolute"
		search_expr="${ASC_01}/"
		;;
	-l)
		mode="relative"
		search_expr="${ASC_01}[^/]+"
		;;
	-n)
		mode="redundant"
		search_expr="(${ASC_01}.*[/]{2,})"
		search_expr="$search_expr|([${ASC_01}/]\./)"
		search_expr="$search_expr|(${ASC_01}.*[^.]+/[.][.]/)"
		search_expr="$search_expr|(${ASC_01}/[.][.]/)"
		search_expr="$search_expr|(${ASC_01}.*[.]{3,}/[.][.]/)"
		search_expr="$search_expr|(${ASC_01}.+/$)"
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
. "$script_dir"/supprt/getfpf "$argsToPassOn"
EPWD=$(pwd | sed 's#/#\\/#g')
case "$mode" in
suspect)
	FPF="$FPF ->\1%p\1%l"
	;;
absolute | relative | redundant)
	FPF="$FPF ->\1%l"
	;;
esac
find "$@" -type l ! -name "*$LF*" -printf "$FPF\n" |
	sort -u |
	case "$mode" in
	dangling)
		while read; do
			file="$REPLY"
			[ -e "$file" ] || echo $file
		done |
			tr '\n' '\0' |
			xargs -r0 ls -lUd -- |
			sed 's/.*[0-9]\{2\} \(.* ->.*\)/\1/'
		;;
	suspect)
		grep "${ASC_01}.*${ASC_01}/" |
			sed -e "s/${ASC_01}.\//${ASC_01}$EPWD\//g" |
			grep -E "${ASC_01}(.*)/[^/]+${ASC_01}\1" |
			sed -e "s/${ASC_01}.*${ASC_01}/ /g"
		;;
	absolute | relative | redundant)
		grep -E "$search_expr" |
			tr '\1' ' '
		;;
	esac
