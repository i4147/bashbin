#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
nvim --headless -c "lua require('mason').setup()" -c "MasonUninstall black" -c qall
