#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
FNAME="$@"
ffmpeg -i "$FNAME" -af "volume=2.0" "${FNAME}_1.mp4"
