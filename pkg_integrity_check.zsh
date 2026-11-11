#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
apt list --installed 2>/dev/null | grep -v "Listing..." | cut -d'/' -f1 | while read pkg; do
	if ! dpkg -V $pkg 2>/dev/null | grep -q "."; then
		:
	else
		echo "Issues found in: $pkg"
		dpkg -V $pkg
	fi
done
