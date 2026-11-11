#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
gs -dSAFER -dBATCH -dNOPAUSE -sDEVICE=jpeg -r300 -sOutputFile=page%d.jpg "$@"
