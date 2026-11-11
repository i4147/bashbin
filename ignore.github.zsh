#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
git rm -r --cached .github/
echo ".github/" >>.gitignore
git add .gitignore
