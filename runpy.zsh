#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
find . -type f -name '*.py' -print |	while IFS= read -r file; do
	printf 'running %s\n' "$file"
	python -I "$file"
done
