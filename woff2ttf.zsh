#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
DIR="${1:-.}"
find "$DIR" -type f -name "*.woff" | while read -r woff_file; do
	ttf_file="${woff_file%.woff}.ttf"
	if [ -f "$ttf_file" ]; then
		echo "⚠ Skipping: $woff_file (TTF already exists)"
		continue
	fi
	echo "Converting: $woff_file"
	fontforge -lang=ff -c "
        Open(\"$woff_file\");
        Generate(\"$ttf_file\");
        Close();
    " 2>/dev/null
	if [ $? -eq 0 ] && [ -f "$ttf_file" ]; then
		echo "  ✓ Created: $ttf_file"
		rm "$woff_file"
	else
		echo "  ✗ Failed: $woff_file"
	fi
done
echo "Done!"
