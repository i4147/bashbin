#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
git log --after="2023-12-31" --reverse --format="%H" | head -n 1
git checkout --orphan temp_branch $1
git commit -m "New root commit (Jan 2024)"
git rebase --onto temp_branch $1 main
git branch -D temp_branch
git push -f origin main
