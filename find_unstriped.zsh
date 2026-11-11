#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
echo "searching for unstripped binnaries in current dir"
fd -tf . --batch-size=12 -X file {} | grep 'ELF.*not stripped'
