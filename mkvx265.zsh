#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
ffmpeg -i "$@" \
	-c:v libx265 -preset veryfast -crf 30 \
	-vf scale=854:-1 \
	-c:a aac -b:a 64k \
	output_480p_x265.mp4
