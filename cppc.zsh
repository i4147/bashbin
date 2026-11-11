#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
g++ -std=c++17 -Wall -Wextra -O2 "$@"
