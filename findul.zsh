#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
script_dir=$(dirname "$0")
script_dir=$(readlink -f "$script_dir")
. "$script_dir"/supprt/fslver
Usage() {
	ProgName=$(basename "$0")
	echo "Find possible redundant (Unused) Libraries.
Usage: $ProgName
Note BE SURE you know a library is not needed before deleting it.
For e.g. this tool doesn't recognise libraries that are only referenced
at runtime (for e.g. plugins)."
	exit
}
TMP=${TMPDIR:-/tmp}
trap 'rm -f $TMP/all_libs $TMP/all_used_libs $TMP/unused_and_referenced_libs \
> /dev/null 2>&1' 0
trap "exit 2" 1 2 3 15
for arg; do
	case "$arg" in
	-h | --help | -help)
		Usage
		;;
	-v | --version)
		Version
		;;
	*)
		Usage
		;;
	esac
done
rm -f "$TMP/all_libs"
lib_dirs=$(. "$script_dir"/supprt/getffl)
find $lib_dirs -type f -follow -name '*.so*' -printf '%p\t%i\n' |
	sort -k2,2n |
	uniq -f1 >"$TMP/all_libs"
rm -f "$TMP/all_used_libs"
find $(. "$script_dir"/supprt/getffp) -xdev -type f -perm /111 |
	xargs ldd |
	cut -s -f3 -d' ' |
	grep -F / |
	sort |
	uniq |
	xargs -i find {} -follow -printf '%p\t%i\n' |
	sort -k2,2n |
	uniq -f1 >"$TMP/all_used_libs"
rm -f "$TMP/unused_and_referenced_libs"
cat "$TMP/all_libs" "$TMP/all_used_libs" |
	sort -k2,2n -u >"$TMP/unused_and_referenced_libs"
cat "$TMP/all_used_libs" "$TMP/unused_and_referenced_libs" |
	sort -k2,2n |
	uniq -u -f1 |
	cut -f1 |
	sort |
	if [ ! -p /proc/self/fd/1 ]; then
		xargs -r ls -lUb --color=auto --
	else
		cat
	fi
