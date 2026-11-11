#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
gh repo list $@ --json name,stargazerCount,languages |
	jq -r '.[] | select(.languages=="Python") | "\(.stargazerCount) \(.name)"' |
	sort -rn | awk '{print $2}'
