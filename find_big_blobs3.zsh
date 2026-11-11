#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
git log --all --pretty=format: --name-only --diff-filter=A | sort | uniq | while read filename; do
	echo "$(git log -1 --format=%H -- "$filename") $filename"
	git log --all --format=%H -- "$filename" | while read commit; do
		size=$(git cat-file -s $(git ls-tree -r "$commit" -- "$filename" | awk '{print $3}' | cut -f1))
		echo "  $commit: $(numfmt --to=iec $size 2>/dev/null || echo $size bytes)"
	done
done
