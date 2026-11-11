#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
script_dir=$(dirname "$0")
script_dir=$(readlink -f "$script_dir")
. "$script_dir"/supprt/fslver
Usage() {
	ProgName=$(basename "$0")
	echo "find dUPlicate files.
Usage: $ProgName [[[-t [-m|-d]] | [--summary]] [-r] [-f] paths(s) ...]
If no path(s) specified then the current directory is assumed.
When -m is specified any found duplicates will be merged (using hardlinks).
When -s is specified any found duplicates will be replaced (using symlinks).
When -d is specified any found duplicates will be deleted (leaving just 1).
When -t is specfied, only report what -m or -d would do.
When --summary is specified change output format to include file sizes.
You can also pipe this summary format to "$script_dir"/fstool/dupwaste
to get a total of the wastage due to duplicates.
Examples:
search for duplicates in current directory and below
    findup or findup .
search for duplicates in all linux source directories and merge using hardlinks
    findup -m /usr/src/linux*
same as above but don't look in subdirectories
    findup -r .
search for duplicates in /usr/bin
    findup /usr/bin
search in multiple directories but not their subdirectories
    findup -r /usr/bin /bin /usr/sbin /sbin
search for duplicates in \$PATH
    findup \$("$script_dir"/supprt/getffp)
exclude zero length files from the search
    findup / -size +0c
search system for duplicate files over 100K in size
    findup / -size +100k
search only my files (that I own and are in my home dir)
    findup ~ -user \$(id -u)
search system for duplicate files belonging to roger
    findup / -user \$(id -u roger)"
	exit
}
cleanup_sum() {
	sed '
    # md5sum and sha1sum et. al. from coreutils at least,
    # to deal with \n in filenames, convert any \ and \n chars
    # to \\ and \\n respectively. Currently we ignore files with \n
    # so just undo this problematic escaping
    /^\\/{s/.//; s/\\\\/\\/g};
    # These utils also add a "*" flag character for normal files
    # on platforms where O_BINARY is significant (like CYGWIN).
    # We always process in binary mode and so remove that flag here
    s/^\([^ ]*\) \*/\1  /;
    '
}
for arg; do
	case "$arg" in
	-h | --help | -help)
		Usage
		;;
	-v | --version)
		Version
		;;
	--summary)
		mode="summary"
		;;
	--gui)
		gui=1
		;;
	-m)
		mode="merge"
		;;
	-d)
		mode="del"
		;;
	-s)
		mode="symlink"
		;;
	-t)
		t="t"
		;;
	*)
		argsToPassOn="$argsToPassOn $(shell_quote "$arg")"
		;;
	esac
done
sep_mode="separate"
if [ "$mode" = "summary" ]; then
	merge_early="-u"
fi
. "$script_dir"/supprt/getfpf "$argsToPassOn"
check_uniq
dev_id="$(find /bin/sh -printf '%D' 2>/dev/null)"
if [ "$dev_id" = "D" ] || [ ! "$dev_id" ]; then
	devFmt="\060"
else
	devFmt=%D
fi
find -H "$@" -type f ! -name "*$LF*" -printf "$FPF\0$devFmt\0%i\0%s\n" |
	sort -u |
	tr ' \t\0' '\0\1 ' |
	sort -k4,4nr -k2,2n -k3,3 $merge_early |
	if [ -z "$merge_early" ]; then
		"$script_dir"/supprt/rmlint/merge_hardlinks
	else
		uniq -3 -D
	fi |
	sort -k2,2n -k3,3n |
	cut -f1 -d' ' -s |
	tr '\0\1\n' ' \t\0' |
	if "$script_dir"/supprt/md5sum_approx </dev/null 2>/dev/null; then
		xargs -r0 "$script_dir"/supprt/md5sum_approx |
			sort |
			uniq --all-repeated -w32 |
			cut -d' ' -f3- |
			sort |
			tr '\n' '\0'
	else
		cat
	fi |
	xargs -r0 md5sum -- |
	cleanup_sum |
	sort |
	uniq --all-repeated=$sep_mode -w32 |
	cut -s -d' ' -f3- |
	sort |
	tr '\n' '\0' |
	xargs -r0 sha1sum -- |
	cleanup_sum |
	sort |
	uniq --all-repeated=$sep_mode -w40 |
	cut -d' ' -f3- |
	if [ "$gui" ]; then
		cat
	elif [ "$mode" ]; then
		"$script_dir"/supprt/rmlint/merge_hardlinks --non-gui |
			if [ ! $mode = "summary" ]; then
				if "$script_dir"/supprt/rmlint/fixdup </dev/null 2>/dev/null; then
					"$script_dir"/supprt/rmlint/fixdup $t$mode
				elif "$script_dir"/supprt/rmlint/fixdup.sh </dev/null 2>/dev/null; then
					"$script_dir"/supprt/rmlint/fixdup.sh $t$mode
				else
					echo "Error, couldn't execute merge util" >&2
					exit 1
				fi
			else
				(
					line=''
					typeset -i counter
					counter=0
					while read; do
						file="$REPLY"
						if [ ! "$file" ]; then
							if [ ! -z "$line" ]; then
								echo "$counter * $line"
							fi
							counter=0
						else
							if [ $counter -eq 0 ]; then
								line=$(du -B1 "$file")
							else
								line="$line $file"
							fi
							counter=counter+1
						fi
					done
					if [ ! -z "$line" ]; then
						echo "$counter * $line"
					fi
				) |
					sort -k3,3 -k1,1 -brn
			fi
	else
		"$script_dir"/supprt/rmlint/merge_hardlinks --non-gui
	fi
