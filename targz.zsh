#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
folder="$(basename "$PWD")"
tar -cf - . | gzip >"../${folder}.tar.gz"
rm -rf ./*
