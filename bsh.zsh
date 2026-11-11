#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
fd -e sh -e SH -e bash -e BASH -e complestion --batch-size 12 -X shfmt -w {}
