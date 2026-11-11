#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
cleanlog() {
	if [ -f "$1" ]; then
		sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$1" | col -b >"${1}_cleaned.log"
		echo "Cleaned log saved to ${1}_cleaned.log"
	else
		echo "File not found."
	fi
}
cleanlog
