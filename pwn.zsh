#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
prettier --with-node-modules --no-bracket-spacing --write --ignore-path ~/.prettierignore .
