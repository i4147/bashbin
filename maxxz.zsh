#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
xz -9e -T0 --memlimit-compress=80% -v "$@"
