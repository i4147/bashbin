#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
script_dir=$(dirname "$0")
script_dir=$(readlink -f "$script_dir")
. "$script_dir"/supprt/fslver
Usage() {
	ProgName=$(basename "$0")
	echo "find (files) with duplicate or conflicting names.
Usage: $ProgName [-A -c -C] [[-r] [-f] paths(s) ...]
If no arguments are supplied the \$PATH is searched for any redundant
or conflicting files.
-A reports all aliases (soft and hard links) to files.
If no path(s) specified then the \$PATH is searched.
If only path(s) specified then they are checked for duplicate named
files. You can qualify this with -C to ignore case in this search.
Qualifying with -c is more restrictive as only files (or directories)
in the same directory whose names differ only in case are reported.
I.E. -c will flag files & directories that will conflict if transfered
to a case insensitive file system. Note if -c or -C specified and
no path(s) specifed the current directory is assumed."
	exit
}
mode="matchFilenames"
uniqsep=prepend
topipe=no
if [ -p /proc/self/fd/1 ]; then
	topipe=yes
fi
if [ $# -eq "0" ]; then
	mode="path"
	eval set -- $(. "$script_dir"/supprt/getffp)
	FPF="%p"
elif [ $# -eq "1" ] && [ "$1" = "-A" ]; then
	mode="aliases"
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
		-C)
			uniq_ignore_case="-i"
			sort_ignore_case="-f"
			;;
		-c)
			mode="casePortability"
			;;
		-A)
			mode="aliases"
			;;
		*)
			argsToPassOn="$argsToPassOn $(shell_quote "$arg")"
			;;
		esac
	done
	if [ $topipe = yes ]; then
		. "$script_dir"/supprt/getfpf -f "$argsToPassOn"
	else
		. "$script_dir"/supprt/getfpf "$argsToPassOn"
	fi
fi
check_uniq
translate() {
	case "$1" in
	safe)
		tr ' \t\n\1\0' '\2\3\4 \n'
		;;
	safe2pipe)
		tr '\2\3\4\n' ' \t\n\0'
		;;
	safe2human)
		tr '\2\3\4' ' \t\n'
		;;
	esac
}
auto_ignore_paths() {
	echo "-true"
	echo "
   /usr/bin/ccache
   /usr/bin/consolehelper
   /usr/sbin/lvm
   /sbin/lvm.static
   " | sed '/ *#/d; /^ *$/d' |
		while IFS= read -r entry_path; do
			inode=$(find "$entry_path" -printf "%i" 2>/dev/null)
			[ "$inode" ] && echo -n " -and ! -inum $inode"
		done
}
case "$mode" in
casePortability)
	find -H "$@" \( -type d -o -type f \) -printf "%f\1$FPF\1%h\0" |
		sort -zu |
		translate safe |
		sort -b -k3,3 -k1,1f |
		uniq -2 -D |
		uniq -i --all-repeated=$uniqsep |
		cut -f2 -d' '
	;;
matchFilenames)
	find -H "$@" -type f -printf "$FPF\1%f\0" |
		sort -zu |
		translate safe |
		sort $sort_ignore_case -k2,2 |
		uniq --all-repeated=$uniqsep -1 $uniq_ignore_case
	;;
path)
	find "$@" \( -type f -o -type l \) -follow \( $(auto_ignore_paths) \) \
		-printf "$FPF\1%i\1%f\0" |
		sort -zu |
		translate safe |
		sort -k3,3 -k2,2n |
		uniq -D -2 |
		uniq -1 |
		uniq --all-repeated=$uniqsep -2
	;;
aliases)
	find "$@" \( -type f -o -type l \) -follow -printf "$FPF\1%i\0" |
		sort -zu |
		translate safe |
		sort -k2,2n |
		uniq --all-repeated=$uniqsep -1
	;;
esac |
	cut -f1 -d' ' |
	if [ $topipe = yes ]; then
		translate safe2pipe
	else
		sed '/^ *$/d' |
			translate safe2pipe |
			xargs -r0 ls -lbUd --color=auto --
	fi
