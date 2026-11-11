#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
#aria2c -x 16 -s 16 -k 1M --min-split-size=1M --max-connection-per-server=16 \
#  --split=16 --continue=true "$@"
aria2c -s 4 "$@"
