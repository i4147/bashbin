#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
gh search repos "$@" --limit 20 --json url,size | jq -r '.[] | "\(.url) \(.size)"' >>"$@".txt
echo "check $@"
