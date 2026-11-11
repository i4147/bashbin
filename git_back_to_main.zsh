#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
git switch -c temp-branch
git switch main
git merge temp-branch
git branch -d temp-branch
