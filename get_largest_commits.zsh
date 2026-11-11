#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
git log --format='%H' |
	while read c; do
		echo "$(git show --shortstat --oneline --format='' "$c" |
			awk '/files? changed/ {
                add+=$4;
                del+=$6;
                print add+del
            }') $c"
	done |
	sort -nr |
	head -5
