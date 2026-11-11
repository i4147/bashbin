#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
wget --progress=bar --adjust-extension --convert-links -r "$@"
