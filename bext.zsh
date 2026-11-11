#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
echo "building ext module"
python setup.py build_ext --inplace
echo "done"
