#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
for f in *.png; do timg $f; done
for f in *.jpg; do timg $f; done
