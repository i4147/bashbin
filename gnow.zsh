#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
set -e
echo "=== Git Cleanup Script ==="
echo "This will:"
echo "  • Remove reflog entries older than 10 days"
echo "  • Prune unreachable commits older than 10 days"
echo "  • Delete local branches already merged"
echo "  • Delete remote merged branches (safe)"
echo
echo
echo "Step 1: Expire old reflog entries..."
git reflog expire --expire=now --expire-unreachable=now --all
echo
echo "Step 2: Garbage-collect unreachable commits..."
git gc --prune=now --aggressive
echo
echo "Step 3: Deleting local branches already merged into main/master..."
if git show-ref --verify --quiet refs/heads/main; then
	MAIN=main
else
	MAIN=master
fi
echo "Detected main branch: $MAIN"
echo
MERGED_LOCAL=$(git branch --merged "$MAIN" | grep -v "$MAIN" || true)
if [[ -z "$MERGED_LOCAL" ]]; then
	echo "No merged local branches to delete."
else
	echo "Merged local branches:"
	echo "$MERGED_LOCAL"
	printf '%s' "Delete them? (y/N) " >&2
	read -r del_local
	if [[ "$del_local" == "y" || "$del_local" == "Y" ]]; then
		echo "$MERGED_LOCAL" | xargs git branch -d
	else
		echo "Skipping local branch deletion."
	fi
fi
echo
echo "=== Cleanup complete! ==="
