#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
if [ -d "$1" ]; then
	dir="$1"
	cd "$dir"
else
	dir="."
fi
find $dir -maxdepth 1 \( -type l -or -type f \) -printf "%s\t%P\n" |
	sort -k1,1n |
	cut -s -f2- |
	tr '\n' '\0' |
	xargs -r0 ls -lU --color=auto --
