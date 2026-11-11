#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
git rev-list --objects --all |
	git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' |
	awk '$1=="blob"{print $3,$4}' |
	sort -nr |
	head -20
