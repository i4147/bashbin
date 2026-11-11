#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
if [ -z "$1" ]; then
	echo "Usage: $0 <video.mkv|video.mp4>"
	exit 1
fi
INPUT="$1"
command -v ffmpeg >/dev/null 2>&1 || {
	echo "ffmpeg is required but not installed."
	exit 1
}
BASENAME="${INPUT%.*}"
SUBS=( "${(@f)$(ffprobe -v error \
	-select_streams s \
	-show_entries stream=index:stream_tags=language \
	-of csv=p=0 "$INPUT")}" )
if [ ${#SUBS[@]} -eq 0 ]; then
	echo "No subtitle streams found."
	exit 0
fi
COUNT=0
for LINE in "${SUBS[@]}"; do
	INDEX=$(echo "$LINE" | cut -d',' -f1)
	LANG=$(echo "$LINE" | cut -d',' -f2)
	[ -z "$LANG" ] && LANG="und"
	OUT="${BASENAME}.sub${COUNT}.${LANG}.srt"
	echo "Extracting subtitle stream $INDEX -> $OUT"
	ffmpeg -y -i "$INPUT" -map 0:s:$COUNT "$OUT" 2>/dev/null
	COUNT=$((COUNT + 1))
done
echo "Done."
