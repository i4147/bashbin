#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
export MATURIN_PEP517_ARGS="--target armv7-linux-androideabi"
python -m maturin build --release -v --target armv7-linux-androideabi
