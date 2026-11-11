#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
gh repo list $@ --json name,description,url,language | jq -r '.[] | select(.language=="Python") | .name'
