#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
dir=${*-.}
du -all -b --max-depth=1 $dir --exclude=$dir | sort -k1,1nr
