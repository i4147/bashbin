#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
fd -e pyc --batch-size=99 -X rm -v {}
fd -td __pycache__ -x rm -rfv {}
