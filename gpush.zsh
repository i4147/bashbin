#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
git add *
echo 'Enter the commit message:'
read commitMessage
git commit -m "$commitMessage"
git push
