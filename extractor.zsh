#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
for archive in *.tar.gz; do
	[[ -f "$archive" ]] || continue
	tar -xvf "$archive" && rm -v -- "$archive"
done
