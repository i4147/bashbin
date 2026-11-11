#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
ls -lLa $1 | grep '^[^cbt]' | (while read p x u g s m d y n; do echo "$n       $s   $m $d $y"; done)
