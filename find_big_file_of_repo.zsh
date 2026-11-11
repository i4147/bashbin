#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
git rev-list --objects --all |
	git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' |
	awk '/^blob/ {if($3 > 10485760) print $3/1048576 " MB", $4}' |
	sort -rn
