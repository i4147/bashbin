#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
git log --all --numstat --pretty=format:"%H %s" |
	awk '/^[0-9]/ {if($1+$2 > 10485760) print}'
