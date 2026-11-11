#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
DIR="${1:-.}"
find "$DIR" -type f -name "*.otf" | while read -r otf_file; do
	ttf_file="${otf_file%.otf}.ttf"
	if [ -f "$ttf_file" ]; then
		echo "⚠ Skipping: $otf_file (TTF already exists)"
		continue
	fi
	echo "Converting: $otf_file"
	fontforge -lang=ff -c "
        Open(\"$otf_file\");
        Generate(\"$ttf_file\");
        Close();
    " 2>/dev/null
	if [ $? -eq 0 ] && [ -f "$ttf_file" ]; then
		echo "  ✓ Created: $ttf_file"
		rm "$otf_file"
	else
		echo "  ✗ Failed: $otf_file"
	fi
done
echo "Done!"
