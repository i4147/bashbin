#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
autoflake --in-place --ignore-init-module-imports --remove-all-unused-imports -r -j 4 .
