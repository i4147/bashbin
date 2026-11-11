#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
TARGET_DIR="${PREFIX:-/data/data/com.termux/files/usr}"
echo "🧹 Sweeping for Python cache files in $TARGET_DIR..."
find "$TARGET_DIR" -name "__pycache__" -type d -exec rm -rf {} +
find "$TARGET_DIR" -name "*.pyc" -delete
find "$TARGET_DIR" -name "*.pyo" -delete
echo "✨ Termux is now clean!"
