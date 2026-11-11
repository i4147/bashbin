#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
export PYTHONDONTWRITEBYTECOMPILE=1
python -m pip install --no-deps --force-reinstall "$@"
rm "$@"
