#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
chmod +x configure
make clean
./configure --prefix="/data/data/com.termux/files/home/.local"
make -j4
make install
