#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
echo "searching for unstripped binarries and auto strip them"
fd -tf . --batch-size=12 -X file {} | grep 'ELF.*not stripped' | cut -d: -f1 | xargs strip
