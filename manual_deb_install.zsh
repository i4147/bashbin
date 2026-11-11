#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
pkg show tur-packages/python-cryptography
wget https://packages.termux.org/apt/termux-main/pool/main/p/python-cryptography/python-cryptography_38.0.1_arm.deb
dpkg -i python-cryptography_38.0.1_arm.deb
pkg install -f
