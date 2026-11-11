#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
fd -e tar.xz -e tar.gz -e tar.zst -e tar.bz2 -e tar.7z -e tar.bz -e tar.lzma -x tar -xvf {}
fd -e tar -x tar -xvf {}
fd -e zst -x zstd --rm -d {}
fd -e xz -x xz -d {}
fd -e gz -x gunzip{}
fd -e tar -x tar -xvf {}
fd -e br -x ubr {}
