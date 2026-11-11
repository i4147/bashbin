#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
sh "/data/data/com.termux/files/usr/libexec/mc/mc-wrapper.sh"
mchist
