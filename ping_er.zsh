#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
nslookup github.com 1.1.1.1
nslookup github.com 8.8.8.8
ping -c 3 1.1.1.1
