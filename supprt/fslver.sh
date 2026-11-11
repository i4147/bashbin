#!/data/data/com.termux/files/usr/bin/bash
set -e
LF='
'
shell_quote() {
	printf '"'
	echo -n "$*" | sed 's/\([`"$\]\)/\\\1/g'
	printf '"'
}
export LC_CTYPE=C
export LC_COLLATE=C
export GREP_USE_DFA=1
Version() {
	echo "FSlint 2.47" && exit
}
check_uniq() {
	echo | uniq --all-repeated=prepend >/dev/null 2>&1 ||
		{
			echo "Error: uniq must have --all-repeated=prepend option. \
  Get the latest version from GNU coreutils or textutils-2.0.21" >&2
			exit 1
		}
}
