#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
trr() {
	local name="$(basename "$PWD")"
	local archive="../${name}.tar"
	echo "Compressing '$name' into '$archive'..."
	tar -cvf "$archive" -C .. "$name" || {
		echo "❌ Compression failed."
		exit 1
	}
	cd .. || {
		echo "❌ Failed to change directory."
		exit 1
	}
	rm -rf "$name"
	xzz "${name}.tar"
	echo "✅ Done: created '${name}.tar.zst' and removed '$name/'"
}
for dir in */; do (cd "$dir" && trr); done
