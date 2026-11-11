#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
gh search repos "language:Jupyter-Notebook stars:>100" \
	--sort stars \
	--order desc \
	--limit 50
