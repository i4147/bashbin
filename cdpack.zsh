#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
for dir in *; do
	[[ -d "$dir" ]] || continue
	(cd -- "$dir" && wheel pack .)
done
