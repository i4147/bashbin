#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
zstd --rm --ultra -19 --progress --format=zstd "$@"
