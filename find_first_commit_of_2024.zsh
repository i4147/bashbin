#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
git log --after="2023-12-31" --reverse --format="%H" | head -n 1
