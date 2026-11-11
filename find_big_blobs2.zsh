#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
git log -S 100000 --all -p -- '*.bin'
git diff HEAD~10 HEAD --stat
