#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
pip install \
	"notebook==6.5.7" \
	"jupyter-client==7.4.9" \
	"jupyter-core==4.12.0" \
	"jupyterlab==3.6.7" --verbose --no-deps
