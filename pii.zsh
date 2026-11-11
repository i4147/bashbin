#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
python -m pip install --no-deps --force-reinstall  --no-compile --verbose "$@" -i https://mirror-pypi.runflare.com "$@"
