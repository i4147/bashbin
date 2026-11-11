#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
script_dir=$(dirname "$0")
script_dir=$(readlink -f "$script_dir")
. "$script_dir"/supprt/fslver
Usage() {
	ProgName=$(basename "$0")
	echo "Shrink Directories.
Usage: $ProgName [[-r] paths(s) ...]
NB make sure that you don't process directories that are
being referenced by running processes, as this utility
will move directories from their current locations (for
a "small" amount of time). Run only in single user mode
if you are not sure of the consequences.
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
if [ $(id -u) != "0" ]; then
	echo "Sorry, root permission is required." >&2
	exit 1
fi
cpio --version >/dev/null 2>&1 ||
	{
		echo "Sorry, cpio is required." >&2
		exit 1
	}
ESC=$(printf "\x1b[")
mvStatus=good
rm -Rf /tmp/fslint2
mkdir /tmp/fslint1 /tmp/fslint2 2>/dev/null
mv -f --target-directory=/tmp/fslint2 /tmp/fslint1 2>/dev/null || mvStatus=bad
rm -Rf /tmp/fslint2
if [ $mvStatus = "bad" ]; then
	echo "Sorry, you need a newer GNU fileutils"
	exit
fi
set -f
. "$script_dir"/supprt/getfpf -f "$argsToPassOn"
bin=$(find -H /bin -maxdepth 0 -printf "%i")
lin=$(find -H /lib -maxdepth 0 -printf "%i")
din=$(find -H /dev -maxdepth 0 -printf "%i")
lfin=$(find -H /lost+found -maxdepth 0 -printf "%i")
mntin="1"
export totalSavedBytes=0
find -H $findArgs -type d -size +2b -depth \( -fstype ext2 -o -fstype ext3 \) \
	-xdev \( ! -inum $bin ! -inum $lin ! -inum $din ! -inum $lfin ! -inum $mntin \) \
	-printf "$FPF\n" |
	tr ' \t' '\1\2' |
	while read; do
		dir=$(echo "$REPLY" | tr '\1\2' ' \t')
		find "$dir" -maxdepth 0 -printf "%7s -> "
		origsize=$(find "$dir" -maxdepth 0 -printf "%s")
		basedir=$(basename "$dir")
		basepath=$(dirname "$dir")
		tmpdir=fslint.shrink
		tmpnewdir=$tmpdir/"$basedir"
		cd "$basepath"
		mkdir $tmpdir
		echo "$basedir" | cpio -pam $tmpdir 2>/dev/null
		find "$basedir" -maxdepth 1 -mindepth 1 -print0 |
			xargs -r0 mv -f --target-directory="$tmpnewdir"
		rmdir "$basedir"
		mv "$tmpnewdir" "$basedir"
		rmdir $tmpdir
		cd -
		new_size=$(find "$dir" -maxdepth 0 -printf "%s")
		diffsize=$(expr $origsize - $new_size)
		if [ $diffsize != "0" ]; then
			find "$dir" -maxdepth 0 -printf "${ESC}31m%7s${ESC}0m (bytes) %p\n"
			totalSavedBytes=$(expr $diffsize + $totalSavedBytes)
		else
			find "$dir" -maxdepth 0 -printf "%7s (bytes) %p\n"
		fi
	done
