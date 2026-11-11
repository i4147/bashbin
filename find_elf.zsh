#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
echo "searching for ELF files ..."
fd -tf --batch-size=32 -X file {} | grep 'ELF'
