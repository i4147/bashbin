#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
command -v ffmpeg >/dev/null 2>&1 || {
	echo "ffmpeg is required but not installed."
	exit 1
}
for wav in *.wav; do
	[ -e "$wav" ] || continue
	mp3="${wav%.wav}.mp3"
	echo "Converting: $wav -> $mp3 (64 kbps)"
	if ffmpeg -y -i "$wav" -codec:a libmp3lame -ab 64k "$mp3"; then
		rm "$wav"
		echo "Removed original: $wav"
	else
		echo "Failed to convert: $wav"
	fi
done
