#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
git checkout main
git branch | grep -v "main" | xargs git branch -D
git branch -r | grep -v "main" | sed 's/origin\///' | xargs -n 1 git push origin --delete
git fetch --prune
