#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
spkg
python -O -m compileall -j 8 -f pip wheel setuptools regex cython packaging
