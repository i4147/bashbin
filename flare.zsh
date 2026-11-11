#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
pip config --user set global.index https://mirror-pypi.runflare.com/simple
pip config --user set global.index-url https://mirror-pypi.runflare.com/simple
pip config --user set global.trusted-host mirror-pypi.runflare.com
