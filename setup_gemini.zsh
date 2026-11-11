#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
set -e
PROJECT_ID="ypy147proj03"
ENV_FILE=".env"
echo "🚀 Step 1: Creating project '$PROJECT_ID'..."
gcloud projects create "$PROJECT_ID"
echo "🎯 Step 2: Setting '$PROJECT_ID' as the active project..."
gcloud config set project "$PROJECT_ID"
echo "🔌 Step 3: Enabling the Gemini API (Generative Language API)..."
gcloud services enable ://googleapis.com
echo "🔑 Step 4: Creating a new API key..."
KEY_RESOURCE=$(gcloud services api-keys create --display-name="Gemini Key" --format="value(name)")
if [ -z "$KEY_RESOURCE" ]; then
	KEY_RESOURCE=$(gcloud services api-keys list --filter="displayName='Gemini Key'" --format="value(name)" | head -n 1)
fi
echo "👁️ Step 5: Extracting the raw API key text..."
RAW_KEY=$(gcloud services api-keys get-key-string "$KEY_RESOURCE")
echo "💾 Step 6: Saving key to $ENV_FILE..."
echo "GEMINI_API_KEY=\"$RAW_KEY\"" >"$ENV_FILE"
echo "✅ Process complete! Your project is ready and the key is stored in your local .env file."
