#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
apt search "$@" | grep -E "^[a-zA-Z0-9]" | cut -d"/" -f1
