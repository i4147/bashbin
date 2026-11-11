#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
if [ -z "$1" ]; then
	echo "Error: No directory provided."
	echo "Usage: ./pack_wheel.sh <directory_name>"
	exit 1
fi
TARGET_DIR="$1"
DEST_DIR="$HOME/tmp/whl"
if [ ! -d "$TARGET_DIR" ]; then
	echo "Error: Directory '$TARGET_DIR' does not exist."
	exit 1
fi
if [ ! -d "$DEST_DIR" ]; then
	echo "Error: Destination directory '$DEST_DIR' does not exist."
	exit 1
fi
echo "Packing '$TARGET_DIR'..."
wheel pack "$TARGET_DIR" -d "$DEST_DIR"
if [ $? -eq 0 ]; then
	echo "--------------------------------------------------"
	echo "Success! The .whl file has been stored in: $DEST_DIR"
	ls -lh "$DEST_DIR"/*.whl | tail -n 1
else
	echo "Error: Failed to pack the wheel."
fi
