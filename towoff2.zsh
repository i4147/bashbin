#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
for f in $(fd -e woff -e ttf -e otf -e eot); do
	out="${f%.woff}.woff2"
	fontforge -lang=ff -c "Open(\$1); Generate(\$2);" "$f" "$out"
done
