#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
PKG_NAME="$1"
PYTHON_VERSION="python3.12"
SITE_PACKAGES="/data/data/com.termux/files/usr/lib/$PYTHON_VERSION/site-packages"
ZIP_DIR="/data/data/com.termux/files/usr/lib/$PYTHON_VERSION/site-packages"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
if [ -z "$PKG_NAME" ]; then
	echo -e "${RED}Usage: $0 <package-name>${NC}"
	exit 1
fi
ZIP_FILE="$ZIP_DIR/${PKG_NAME}.zip"
if [ ! -f "$ZIP_FILE" ]; then
	echo -e "${RED}Error: $ZIP_FILE not found.${NC}"
	exit 1
fi
HAS_PY=$(unzip -l "$ZIP_FILE" | grep -q "\.py$" && echo true || echo false)
HAS_PYC=$(unzip -l "$ZIP_FILE" | grep -q "\.pyc$" && echo true || echo false)
if [ "$HAS_PYC" = true ] && [ "$HAS_PY" = false ]; then
	echo -e "${YELLOW}⚠️  Notice: This ZIP contains ONLY bytecode (.pyc).${NC}"
	echo -e "${YELLOW}Source code (.py) will not be recovered, only the executable binary.${NC}"
fi
rm -f "$SITE_PACKAGES/${PKG_NAME}.py"
unzip -qq -o "$ZIP_FILE" -d "$SITE_PACKAGES/"
LIBS_PATH="$ZIP_DIR/${PKG_NAME}_libs"
if [ -d "$LIBS_PATH" ]; then
	cp -r "$LIBS_PATH/"* "$SITE_PACKAGES/"
	rm -rf "$LIBS_PATH"
fi
rm "$ZIP_FILE"
echo -e "${GREEN}✓ $PKG_NAME successfully restored to $SITE_PACKAGES${NC}"
