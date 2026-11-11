#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
while IFS= read -r line; do
	[[ -z "$line" ]] && continue
	srp "$line"
done <"$@"
