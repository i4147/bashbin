#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
dd if=/dev/zero of=/data/data/com.termux/files/usr/tmp/swap bs=1024 count=524288
chmod 600 /data/data/com.termux/files/usr/tmp/swap
mkswap /data/data/com.termux/files/usr/tmp/swap &
swapon /data/data/com.termux/files/usr/tmp/swap
