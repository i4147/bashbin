#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
DIR="${1:-.}"
find "$DIR" -type f -name "*.ttc" | while read -r ttc_file; do
	ttf_file="${ttc_file%.ttc}.ttf"
	if [ -f "$ttf_file" ]; then
		echo "⚠ Skipping: $ttc_file (TTF already exists)"
		continue
	fi
	echo "Converting: $ttc_file"
	fontforge -lang=ff -c "
        Open(\"$ttc_file\");
        Generate(\"$ttf_file\");
        Close();
    " 2>/dev/null
	if [ $? -eq 0 ] && [ -f "$ttf_file" ]; then
		echo "  ✓ Created: $ttf_file"
		rm "$ttc_file"
	else
		echo "  ✗ Failed: $ttc_file"
	fi
done
echo "Done!"
