#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
command -v magick >/dev/null 2>&1 || {
	echo "ImageMagick (magick) is required but not installed."
	exit 1
}
setopt NULL_GLOB
for img in *; do
	case "$img" in
	*.jpg | *.jpeg) continue ;;
	esac
	if magick identify "$img" >/dev/null 2>&1; then
		out="${img%.*}.jpg"
		echo "Converting: $img -> $out"
		if magick "$img" -quality 90 "$out"; then
			rm "$img"
			echo "Removed original: $img"
		else
			echo "Failed to convert: $img"
		fi
	fi
done
