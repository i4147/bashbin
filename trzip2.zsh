#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
dirziper() {
	local name="$(basename "$PWD")"
	local archive="../${name}.zip"
	echo "Compressing '$name' into '$archive'..."
	zip -r -9 "$archive" . || {
		echo "❌ Compression failed."
		exit 1
	}
	cd .. || {
		echo "❌ Failed to change directory."
		exit 1
	}
	rm -rf "$name"
	echo "✅ Done: created '${name}.zip' and removed '$name/'"
}
for dir in */; do (cd "$dir" && dirziper); done
