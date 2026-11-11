#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git repack -a -d --depth=1
