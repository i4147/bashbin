#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
tar -xvf 0.tar.zst --zstd "$@"
tar --delete -f 0.tar.zst --zstd "$@"
