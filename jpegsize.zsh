#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
echo "This script prints the width and height of one or more jpeg image files."
if [ $# -lt 1 ]; then
	echo "Usage: $0 files...." >&2
	exit 1
fi
M_SOF0=0xC0
M_SOF1=0xC1
M_SOF2=0xC2
M_SOF3=0xC3
M_SOF5=0xC5
M_SOF6=0xC6
M_SOF7=0xC7
M_SOF9=0xC9
M_SOF10=0xCA
M_SOF11=0xCB
M_SOF13=0xCD
M_SOF14=0xCE
M_SOF15=0xCF
M_SOI=0xD8
M_EOI=0xD9
read_ushort() {
	local file=$1
	local offset=$2
	local byte1=$(dd if="$file" bs=1 skip=$offset count=1 2>/dev/null | od -A n -t u1 | tr -d ' ')
	local byte2=$(dd if="$file" bs=1 skip=$((offset + 1)) count=1 2>/dev/null | od -A n -t u1 | tr -d ' ')
	echo $(((byte1 << 8) | byte2))
}
is_sof_marker() {
	local marker=$1
	case $marker in
	$M_SOF0 | $M_SOF1 | $M_SOF2 | $M_SOF3 | $M_SOF5 | $M_SOF6 | $M_SOF7 | $M_SOF9 | $M_SOF10 | $M_SOF11 | $M_SOF13 | $M_SOF14 | $M_SOF15)
		return 0
		;;
	*)
		return 1
		;;
	esac
}
get_jpeg_size() {
	local file=$1
	local offset=0
	local byte1 byte2 marker length
	byte1=$(dd if="$file" bs=1 skip=$offset count=1 2>/dev/null | od -A n -t u1 | tr -d ' ')
	byte2=$(dd if="$file" bs=1 skip=$((offset + 1)) count=1 2>/dev/null | od -A n -t u1 | tr -d ' ')
	if [ "$byte1" != "255" ] || [ "$byte2" != "$M_SOI" ]; then
		return 1
	fi
	offset=2
	while true; do
		byte1=$(dd if="$file" bs=1 skip=$offset count=1 2>/dev/null | od -A n -t u1 | tr -d ' ')
		while [ "$byte1" == "255" ]; do
			offset=$((offset + 1))
			byte1=$(dd if="$file" bs=1 skip=$offset count=1 2>/dev/null | od -A n -t u1 | tr -d ' ')
		done
		marker=$byte1
		offset=$((offset + 1))
		while ! is_sof_marker $marker; do
			if [ "$marker" == "$M_EOI" ] || [ "$marker" == "0xDA" ]; then
				return 1
			fi
			length=$(read_ushort "$file" $offset)
			offset=$((offset + length))
			byte1=$(dd if="$file" bs=1 skip=$offset count=1 2>/dev/null | od -A n -t u1 | tr -d ' ')
			while [ "$byte1" == "255" ]; do
				offset=$((offset + 1))
				byte1=$(dd if="$file" bs=1 skip=$offset count=1 2>/dev/null | od -A n -t u1 | tr -d ' ')
			done
			marker=$byte1
			offset=$((offset + 1))
		done
		length=$(read_ushort "$file" $offset)
		offset=$((offset + 2))
		offset=$((offset + 1))
		height=$(read_ushort "$file" $offset)
		width=$(read_ushort "$file" $((offset + 2)))
		echo "${width}x${height}"
		return 0
	done
}
for file in "$@"; do
	if [ ! -f "$file" ]; then
		echo "$file: file not found" >&2
		continue
	fi
	dimensions=$(get_jpeg_size "$file")
	if [ $? -eq 0 ]; then
		echo "$file: $dimensions"
	else
		echo "$file is not a jpeg file" >&2
	fi
done
