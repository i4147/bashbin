#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
set -euo pipefail
REPO_NAME="$(basename "$PWD")"
# Case 1: Not a git repo → init, commit, create remote repo, push
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	echo "→ Initializing git repo..."
	git init
	git add .
	git commit -m "initial commit"
	gh repo create "$REPO_NAME" --public --source=. --remote=origin --push
	exit 0
fi
# Case 2: Git repo but no 'origin' remote → create repo, push existing commits
if ! git remote get-url origin >/dev/null 2>&1; then
	echo "→ No 'origin' remote, creating repo..."
	# commit any pending changes first (optional)
	if ! git diff --quiet || ! git diff --cached --quiet; then
		git add .
		git commit -m "update"
	fi
	gh repo create "$REPO_NAME" --public --source=. --remote=origin --push
	exit 0
fi
# Case 3: Remote exists → just commit & push
echo "→ Remote exists, committing and pushing..."
if ! git diff --quiet || ! git diff --cached --quiet; then
	git add .
	git commit -m "update"
fi
git push -u origin HEAD
