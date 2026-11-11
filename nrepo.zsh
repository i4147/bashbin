#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
set -euo pipefail
repo_dir="$(pwd)"
repo_name="$(basename "$repo_dir")"
echo "Repository name: $repo_name"
if [ ! -d ".git" ]; then
	git init
fi
current_branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
if [ -z "$current_branch" ]; then
	git checkout -b main
elif [ "$current_branch" != "main" ]; then
	git branch -M main
fi
if [ -f "$HOME/.gitignore" ]; then
	cp -f "$HOME/.gitignore" ./.gitignore
	echo ".gitignore copied from \$HOME"
else
	echo "Warning: \$HOME/.gitignore not found"
fi
if ! gh repo view "$repo_name" >/dev/null 2>&1; then
	gh repo create "$repo_name" --source=. --remote=origin --public --push=false
fi
git add -A
if ! git diff --cached --quiet; then
	commit_msg="$(date '+%Y-%m-%d %H:%M:%S')"
	git commit -m "$commit_msg"
else
	echo "Nothing to commit"
fi
git push -u origin main
echo "Done. Repository pushed to GitHub."
