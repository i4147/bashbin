#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
command -v ffmpeg >/dev/null 2>&1 || {
	echo "ffmpeg is required but not installed."
	exit 1
}
for mp3 in *.mp3; do
	[ -e "$mp3" ] || continue
	tmp="${mp3%.mp3}_64.mp3"
	echo "Converting: $mp3 -> 64 kbps"
	if ffmpeg -y -i "$mp3" -codec:a libmp3lame -ab 64k "$tmp"; then
		mv "$tmp" "$mp3"
		echo "Replaced original with 64 kbps version: $mp3"
	else
		echo "Failed to convert: $mp3"
		rm -f "$tmp"
	fi
done
