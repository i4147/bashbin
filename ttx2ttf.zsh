#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
DIR="${1:-.}"
find "$DIR" -type f -name "*.ttx" | while read -r ttx_file; do
	ttf_file="${ttx_file%.ttx}.ttf"
	if [ -f "$ttf_file" ]; then
		echo "⚠ Skipping: $ttx_file (TTF already exists)"
		continue
	fi
	echo "Converting: $ttx_file"
	fontforge -lang=ff -c "
        Open(\"$ttx_file\");
        Generate(\"$ttf_file\");
        Close();
    " 2>/dev/null
	if [ $? -eq 0 ] && [ -f "$ttf_file" ]; then
		echo "  ✓ Created: $ttf_file"
		rm "$ttx_file"
	else
		echo "  ✗ Failed: $ttx_file"
	fi
done
echo "Done!"
