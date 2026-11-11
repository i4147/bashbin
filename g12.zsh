#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
git clone --depth 1 --single-branch --branch main https://github.com/"$@"
