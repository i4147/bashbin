#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
black -l 120 -W 8 --target-version py312 --preview --verbose .
