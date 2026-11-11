#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
twine upload --verbose -r pypi -u __token__ -p "$PYPI_TOKEN" dist/*
