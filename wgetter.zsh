#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
WEBSITE="$@"
wget -r -l1 -H -nd -A srt,css,js -R vtt "${WEBSITE}"
