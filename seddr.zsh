#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
find . -type f -exec sed -i 's/"$1"/"$2"/g' {} +
