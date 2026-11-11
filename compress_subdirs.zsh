#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
set -euo pipefail
if ! command -v pixz &>/dev/null; then
	echo "Error: pixz is not installed. Install it first:"
	echo "  Ubuntu/Debian: sudo apt install pixz"
	echo "  macOS: brew install pixz"
	echo "  Or use: xz -T0 instead (modify script)"
	exit 1
fi
find . -maxdepth 1 -mindepth 1 -type d ! -name ".*" | while read -r dir; do
	dir_name="${dir#./}"
	echo "Processing: $dir_name"
	archive="${dir_name}.tar.xz"
	echo "  Creating: $archive"
	if tar -cf - -C "$dir_name" . | pixz -9 >"$archive"; then
		if tar -tf "$archive" &>/dev/null; then
			echo "  ✅ Successfully compressed: $archive"
			echo "  Removing: $dir_name/"
			rm -rf "$dir_name"
		else
			echo "  ❌ Archive verification failed: $archive"
			rm -f "$archive"
			exit 1
		fi
	else
		echo "  ❌ Compression failed for: $dir_name"
		rm -f "$archive"
		exit 1
	fi
done
echo "✅ All subdirectories compressed successfully!"
