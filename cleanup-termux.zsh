#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
cd /data/data/com.termux || exit 1
exec $PREFIX/.local/bin/klin
