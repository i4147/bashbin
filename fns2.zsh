#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
fd -t f -x sh -c 'file "$1" | rg -q "ELF" && file "$1"' sh {} | rg 'not stripped'
