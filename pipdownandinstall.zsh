#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
WHL="/data/data/com.termux/files/home/tmp/whl"
mkdir -p "$WHL"
PKG="$@"
python -m pip download --verbose --no-deps "$PKG" -d "$WHL"
python -m pip install --verbose --no-deps "$PKG"
