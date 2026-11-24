#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
yapf -i -p -vv -r --style google -p 8 .
