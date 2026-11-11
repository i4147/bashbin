#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
PYTHONNOBYTECOMPILE=1 python setup.py bdist_eggx
