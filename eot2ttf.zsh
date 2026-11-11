#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
DIR="${1:-.}"
find "$DIR" -type f -name "*.eot" | while read -r eot_file; do
	ttf_file="${eot_file%.eot}.ttf"
	if [ -f "$ttf_file" ]; then
		echo "⚠ Skipping: $eot_file (TTF already exists)"
		continue
	fi
	echo "Converting: $eot_file"
	fontforge -lang=ff -c "
        Open(\"$eot_file\");
        Generate(\"$ttf_file\");
        Close();
    " 2>/dev/null
	if [ $? -eq 0 ] && [ -f "$ttf_file" ]; then
		echo "  ✓ Created: $ttf_file"
		rm "$eot_file"
	else
		echo "  ✗ Failed: $eot_file"
	fi
done
echo "Done!"
