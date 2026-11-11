#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
set -e
ZIP_NAME="termux_configs.zip"
if [[ ! -f "$HOME/$ZIP_NAME" ]]; then
	echo "❌ Error: $ZIP_NAME not found in your Cloud Shell home directory."
	echo "Please upload it first using the terminal's upload menu feature."
	exit 1
fi
echo "⏳ Backing up existing Cloud Shell environment profiles..."
BACKUP_DIR="$HOME/cloudshell_profile_bak_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
# Safe move logic to ensure you don't ruin current working files
[[ -f "$HOME/.bashrc" ]] && mv "$HOME/.bashrc" "$BACKUP_DIR/"
[[ -d "$HOME/.config/bash.d" ]] && mv "$HOME/.config/bash.d" "$BACKUP_DIR/"
[[ -f "$HOME/.nanorc" ]] && mv "$HOME/.nanorc" "$BACKUP_DIR/"
[[ -d "$HOME/.config/nvim" ]] && mv "$HOME/.config/nvim" "$BACKUP_DIR/"
[[ -f "$HOME/.gitconfig" ]] && mv "$HOME/.gitconfig" "$BACKUP_DIR/"
[[ -d "$HOME/.config/gh" ]] && mv "$HOME/.config/gh" "$BACKUP_DIR/"
echo "🔓 Unpacking your Termux environment files..."
cd "$HOME"
unzip -o "$ZIP_NAME"
echo "🧹 Securely wiping down the downloaded installation archive..."
rm -f "$HOME/$ZIP_NAME"
echo "⚡ Reloading terminal environment profile changes..."
# The restored profile is Bash syntax, so source it in a Bash subprocess.
bash -c 'source "$HOME/.bashrc"'
echo "🎉 Finished! All environment paths configurations and configurations are restored."
