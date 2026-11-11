#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
python -m maturin build \
	--target armv7-linux-androideabi \
	--no-default-features \
	--strip \
	--release \
	--interpreter python3.14 \
	--verbose
