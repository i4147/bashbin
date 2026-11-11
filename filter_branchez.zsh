#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
for k in $(git branch | sed /\*/d); do
	if [[ ! $(git log -1 --since='2 weeks ago' -s $k) ]]; then
		git branch -D $k
	fi
done
