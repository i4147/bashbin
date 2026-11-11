#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
ruff --config ~/.config/ruff/ruff.toml check --fix --unsafe-fixes --diff .
ruff clean
