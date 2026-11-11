#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH

# Ensure a file was passed as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_pdf>"
    exit 1
fi

INPUT_FILE="$1"

# Check if the file actually exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found."
    exit 1
fi

# Check if mutool is installed
if ! command -v mutool &> /dev/null; then
    echo "Error: 'mutool' is not installed or not in your PATH."
    exit 1
fi

# Create a temporary file path safely
TMP_FILE=$(mktemp /tmp/pdf_mutool_XXXXXX.pdf)

echo "Optimizing '$INPUT_FILE' with mutool..."

# Execute mutool deep clean and deflate
mutool clean -ggggz "$INPUT_FILE" "$TMP_FILE"

# Get file sizes in bytes (handles both Linux and macOS)
ORIG_SIZE=$(stat -c%s "$INPUT_FILE" 2>/dev/null || stat -f%z "$INPUT_FILE")
COMP_SIZE=$(stat -c%s "$TMP_FILE" 2>/dev/null || stat -f%z "$TMP_FILE")

# Compare sizes and determine whether to overwrite
if [ "$COMP_SIZE" -lt "$ORIG_SIZE" ]; then
    mv "$TMP_FILE" "$INPUT_FILE"
    echo "Success! File optimized and overwritten in-place."
    echo "Original: $((ORIG_SIZE / 1024)) KB -> New: $((COMP_SIZE / 1024)) KB"
else
    rm -f "$TMP_FILE"
    echo "Optimization skipped. The cleaned version ($((COMP_SIZE / 1024)) KB) was not smaller than the original ($((ORIG_SIZE / 1024)) KB)."
fi
