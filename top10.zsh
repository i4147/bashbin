#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
du -h --max-depth=1 "$@" | sort -hr | head -n 10
