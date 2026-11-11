#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
set -euo pipefail
COUNT="${1:-3}"
REMOTE="${2:-origin}"
load_github_token() {
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		return 0
	fi
	local env_file="$HOME/.env"
	if [ -f "$env_file" ]; then
		local token_line
		token_line="$(grep -E '^GITHUB_TOKEN=' "$env_file" | tail -1 || true)"
		if [ -n "$token_line" ]; then
			export GITHUB_TOKEN="${token_line#GITHUB_TOKEN=}"
			GITHUB_TOKEN="${GITHUB_TOKEN%\"}"
			GITHUB_TOKEN="${GITHUB_TOKEN#\"}"
			GITHUB_TOKEN="${GITHUB_TOKEN%\'}"
			GITHUB_TOKEN="${GITHUB_TOKEN#\'}"
			return 0
		fi
	fi
	return 1
}
check_auth() {
	if command -v gh >/dev/null 2>&1; then
		if gh auth status >/dev/null 2>&1; then
			echo "Using gh CLI authentication"
			return 0
		fi
	fi
	if load_github_token; then
		echo "Using GITHUB_TOKEN from ~/.env"
		git config --global credential.helper store
		if command -v gh >/dev/null 2>&1; then
			echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/dev/null || true
		fi
		return 0
	fi
	echo "Error: No authentication method found." >&2
	echo "Either:" >&2
	echo "  1. Run 'gh auth login' to authenticate with GitHub CLI" >&2
	echo "  2. Set GITHUB_TOKEN in ~/.env (format: GITHUB_TOKEN=ghp_xxx)" >&2
	return 1
}
if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -lt 2 ]; then
	echo "Error: COUNT must be an integer >= 2 (got '$COUNT')" >&2
	exit 1
fi
if ! git rev-parse --git-dir >/dev/null 2>&1; then
	echo "Error: Not inside a git repository" >&2
	exit 1
fi
check_auth
TOTAL_COMMITS="$(git rev-list --count HEAD)"
if [ "$COUNT" -gt "$TOTAL_COMMITS" ]; then
	echo "Error: Only $TOTAL_COMMITS commit(s) available, cannot squash $COUNT" >&2
	exit 1
fi
BRANCH="$(git symbolic-ref --short HEAD)"
if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
	echo "Warning: Current branch is '$BRANCH', not 'main' or 'master'." >&2
	printf '%s' "Continue on this branch? (y/N) " >&2
	read -r REPLY
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		exit 1
	fi
fi
REMOTE_URL="$(git remote get-url "$REMOTE" 2>/dev/null || echo "")"
IS_GITHUB=false
if [[ "$REMOTE_URL" == *github.com* ]] || [[ "$REMOTE_URL" == git@github.com:* ]]; then
	IS_GITHUB=true
fi
echo "=== Squashing last $COUNT commits on branch '$BRANCH' ==="
echo "Remote: $REMOTE ($REMOTE_URL)"
TODO_FILE="$(mktemp)"
trap 'rm -f "$TODO_FILE"' EXIT
{
	FIRST_SHA="$(git rev-parse "HEAD~$((COUNT - 1))")"
	FIRST_SUBJECT="$(git log -1 --format=%s "$FIRST_SHA")"
	echo "pick $FIRST_SHA $FIRST_SUBJECT"
	for i in $(seq 1 $((COUNT - 1))); do
		SHA="$(git rev-parse "HEAD~$((COUNT - 1 - i))")"
		SUBJECT="$(git log -1 --format=%s "$SHA")"
		echo "squash $SHA $SUBJECT"
	done
} >"$TODO_FILE"
echo "Running rebase..."
GIT_SEQUENCE_EDITOR="cp $TODO_FILE" GIT_EDITOR=true git rebase -i "HEAD~$COUNT"
TODAY_RFC="$(date -R)"
echo "Setting commit date to: $TODAY_RFC"
GIT_COMMITTER_DATE="$TODAY_RFC" git commit --amend --no-edit --date="$TODAY_RFC"
echo "Pushing to $REMOTE/$BRANCH..."
if [ "$IS_GITHUB" = true ] && [ -n "${GITHUB_TOKEN:-}" ]; then
	if [[ "$REMOTE_URL" == https://github.com/* ]]; then
		REPO_PATH="${REMOTE_URL#https://github.com/}"
		REPO_PATH="${REPO_PATH%.git}"
		PUSH_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO_PATH}.git"
	elif [[ "$REMOTE_URL" == git@github.com:* ]]; then
		REPO_PATH="${REMOTE_URL#git@github.com:}"
		REPO_PATH="${REPO_PATH%.git}"
		PUSH_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO_PATH}.git"
	else
		PUSH_URL=""
	fi
	if [ -n "$PUSH_URL" ]; then
		echo "Using GITHUB_TOKEN for push authentication"
		git push --force-with-lease "$PUSH_URL" "$BRANCH"
	else
		git push --force-with-lease "$REMOTE" "$BRANCH"
	fi
else
	git push --force-with-lease "$REMOTE" "$BRANCH"
fi
echo "=== Done! Squashed $COUNT commits into one and pushed. ==="
echo ""
echo "Recent commits after squash:"
git log --oneline -5
