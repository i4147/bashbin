#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
yes | find . -type f -name \*.zst -not -name \*.tar.zst -execdir zstd --rm -d {} \;
