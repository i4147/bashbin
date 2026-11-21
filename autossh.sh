#!/data/data/com.termux/files/usr/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
#  setup_github_ssh.sh ─ Multi‑account GitHub SSH bootstrapper
#
#  Usage:
#     ./setup_github_ssh.sh <account-label>
#
#  Each <account‑label> gets:
#     • A separate key:   ~/.ssh/id_ed25519_<label>
#     • A host alias:     github-<label>   (so clone via git@github-<label>:...)
#
#  Automatic key upload:
#     1. Generate a Personal Access Token (PAT) with the **admin:public_key** scope
#        – Classic PAT:  https://github.com/settings/tokens
#        – Fine‑grained: Settings ➜ Developer settings ➜ Personal access tokens
#     2. Either:
#        • export GITHUB_TOKEN="ghp_xxx"  (before running), or
#        • Paste the token when prompted.
#
#  The token is **not persisted**; it's used once for the API call.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# Escape paths for SSH config (convert backslashes to slashes, escape spaces)
escape_path_for_ssh_config() {
  local path="$1"
  path="${path//\\//}"   # Backslash to forward slash
  path="${path// /\\ }"  # Escape spaces
  echo "$path"
}

# ─────────────────────────── 0. Parse & sanitise label ───────────────────────
if [[ "${1-}" == "" ]]; then
  read -rp "Account label (e.g. personal, work) [default]: " LABEL
  LABEL="${LABEL:-default}"
else
  LABEL="$1"
fi

if [[ "$LABEL" =~ [^a-zA-Z0-9_-] ]]; then
  echo "❌  Label may only contain letters, numbers, '_' or '-'." >&2
  exit 1
fi

if [[ "$LABEL" == "default" ]]; then
  HOST_ALIAS="github.com"          # Use canonical host for the default label
  KEY_NAME="id_ed25519"
else
  HOST_ALIAS="github-${LABEL}"
  KEY_NAME="id_ed25519_${LABEL}"
fi

SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/$KEY_NAME"
CONFIG_FILE="$SSH_DIR/config"
GITHUB_HOST="github.com"

headline() { printf "\n\033[1;32m%s\033[0m\n" "$*"; }

# ───────────────────────── 1. Verify global Git identity ─────────────────────
headline "🔧 Checking global Git identity"

GIT_USER_NAME="$(git config --global user.name || true)"
GIT_USER_EMAIL="$(git config --global user.email || true)"

if [[ -z "$GIT_USER_NAME" ]]; then
  read -rp "Your full name (git user.name): " GIT_USER_NAME
  git config --global user.name "$GIT_USER_NAME"
  echo "  → Stored globally."
else
  echo "  ✔ user.name: $GIT_USER_NAME"
fi

if [[ -z "$GIT_USER_EMAIL" ]]; then
  read -rp "Email address (git user.email): " GIT_USER_EMAIL
  git config --global user.email "$GIT_USER_EMAIL"
  echo "  → Stored globally."
else
  echo "  ✔ user.email: $GIT_USER_EMAIL"
fi

# ────────────────────── 2. Ensure ~/.ssh & generate / reuse key ──────────────
headline "🗄️  Preparing $SSH_DIR"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ ! -f "$KEY_PATH" ]]; then
  headline "🔑 Generating new SSH key: $KEY_NAME"
  ssh-keygen -t ed25519 -C "$GIT_USER_EMAIL" -f "$KEY_PATH" -N ""
  NEW_KEY=true
else
  headline "✅ Existing key detected: $KEY_PATH"
  NEW_KEY=false
fi

# ─────────────────────────── 3. Load key into ssh-agent ──────────────────────
headline "🚀 Starting ssh-agent and adding the key"
eval "$(ssh-agent -s)"
ssh-add "$KEY_PATH"

# ────────────────────── 4. Append Host block to ~/.ssh/config ────────────────
headline "⚙️  Updating $CONFIG_FILE"
if ! grep -q "Host $HOST_ALIAS" "$CONFIG_FILE" 2>/dev/null; then
  ESCAPED_KEY_PATH=$(escape_path_for_ssh_config "$KEY_PATH")
  {
    echo ""
    echo "Host $HOST_ALIAS"
    echo "  HostName $GITHUB_HOST"
    echo "  IdentityFile $ESCAPED_KEY_PATH"
    echo "  AddKeysToAgent yes"
    echo "  IdentitiesOnly yes"
  } >> "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"
  echo "  → Added block for $HOST_ALIAS"
else
  echo "  ✔ Host block for $HOST_ALIAS already present"
fi

# ────────────── 5. Show public key, prompt for token, optional upload ────────
if [[ "$NEW_KEY" == true ]]; then
  headline "📋 Public key for '$LABEL' (copy if needed)"
  echo "-----------------------------------------------------------------"
  cat "${KEY_PATH}.pub"
  echo "-----------------------------------------------------------------"

  # Token guidance if not preset
  if [[ -z "${GITHUB_TOKEN-}" ]]; then
    echo "🔑 To upload automatically, generate a GitHub PAT with **admin:public_key** scope:"
    echo "   → https://github.com/settings/tokens"
    read -rp "Paste token here (blank to skip auto‑upload): " INPUT_TOKEN
    GITHUB_TOKEN="${INPUT_TOKEN:-}"
  fi

  if [[ -n "${GITHUB_TOKEN}" ]]; then
    headline "☁️  Uploading key via GitHub API"
    RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      https://api.github.com/user/keys \
      -d '{"title":"'"$(hostname)-${LABEL}"'","key":"'"$(cat "${KEY_PATH}.pub")"'"}')

    if echo "$RESPONSE" | grep -q '"id":'; then
      echo "   → Key uploaded successfully."
    else
      echo "   ⚠️  Upload failed or key already exists. Response:"
      echo "$RESPONSE"
      echo "   Please add the key manually at https://github.com/settings/keys"
    fi
  else
    echo "   ⏭️  API upload skipped. Add the key manually at https://github.com/settings/keys"
  fi

  read -rp "Press [Enter] once the key is present in GitHub… " _
fi

# ───────────────────────── 6. Final authentication test ──────────────────────
headline "🧪 Testing SSH connection as $HOST_ALIAS"
SSH_OUTPUT="$(ssh -T git@"${HOST_ALIAS}" 2>&1 || true)"
if echo "$SSH_OUTPUT" | grep -q "successfully authenticated"; then
  headline "🎉 SSH for '$LABEL' is ready!"
  echo "    Clone with: git clone git@${HOST_ALIAS}:<owner>/<repo>.git"
else
  echo "$SSH_OUTPUT"
  headline "⚠️  Authentication failed. Check the messages above."
fi
