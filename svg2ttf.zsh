#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
DIR="${1:-.}"
find "$DIR" -type f -name "*.svg" | while read -r svg_file; do
	ttf_file="${svg_file%.svg}.ttf"
	if [ -f "$ttf_file" ]; then
		echo "⚠ Skipping: $svg_file (TTF already exists)"
		continue
	fi
	echo "Converting: $svg_file"
	fontforge -lang=ff -c "
        Open(\"$svg_file\");
        Generate(\"$ttf_file\");
        Close();
    " 2>/dev/null
	if [ $? -eq 0 ] && [ -f "$ttf_file" ]; then
		echo "  ✓ Created: $ttf_file"
		rm "$svg_file"
	else
		echo "  ✗ Failed: $svg_file"
	fi
done
echo "Done!"
