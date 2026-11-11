#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
python -m pip install --no-deps \
	--no-build-isolations \
	--upgrade \
	--force-reinstall \
	--verbose "$@"
