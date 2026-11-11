#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
ty check --extra-search-path ~/projects/py/dh/src "$@"
