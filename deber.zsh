#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
for package in *.deb; do
	[[ -f "$package" ]] || continue
	dpkg -i "$package" && rm -v -- "$package"
done
