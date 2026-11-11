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

# Termux optimization: Ensure we use Termux's local temp directory
# Fall back to standard home directory tmp if $PREFIX isn't populated
TMP_DIR="${PREFIX:-/data/data/com.termux/files/usr}/tmp"
mkdir -p "$TMP_DIR"

# Create a temporary file safely within Termux boundaries
TMP_FILE=$(mktemp "$TMP_DIR/pdf_compress_XXXXXX.pdf")

echo "Compressing '$INPUT_FILE' for mobile..."

# Execute Ghostscript compression with mobile settings
#gs -sDEVICE=pdfwrite \
#   -dCompatibilityLevel=1.4 \
#   -dPDFSETTINGS=/ebook \
#   -dNOPAUSE -dQUIET -dBATCH \
#   -sOutputFile="$TMP_FILE" "$INPUT_FILE"
# Execute Ghostscript compression with mobile settings and blend fix
gs -sDEVICE=pdfwrite \
   -dCompatibilityLevel=1.4 \
   -dPDFSETTINGS=/ebook \
   -dBlendConversionStrategy=/LeaveColorUnchanged \
   -dNOPAUSE -dQUIET -dBATCH \
   -sOutputFile="$TMP_FILE" "$INPUT_FILE"

# Termux optimization: Toybox/Bionic stat usage
ORIG_SIZE=$(stat -c %s "$INPUT_FILE")
COMP_SIZE=$(stat -c %s "$TMP_FILE")

# Compare sizes and determine whether to overwrite
if [ "$COMP_SIZE" -lt "$ORIG_SIZE" ]; then
    mv "$TMP_FILE" "$INPUT_FILE"
    echo "Success! File overwritten in-place."
    echo "Original: $((ORIG_SIZE / 1024)) KB -> New: $((COMP_SIZE / 1024)) KB"
else
    rm -f "$TMP_FILE"
    echo "Optimization skipped. The compressed version ($((COMP_SIZE / 1024)) KB) was not smaller than the original ($((ORIG_SIZE / 1024)) KB)."
fi
