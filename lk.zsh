#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
ls -la | awk '{printf "%-20s %-10s\n", $5, $9}'
