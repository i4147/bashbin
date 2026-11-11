#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
find /data/data/com.termux/files/usr/lib/python3.12/site-packages -type f -name \*.pyc -execdir rm -v {} \;
find /data/data/com.termux/files/home -type f -name \*.pyc -execdir rm -v {} \;
find /sdcard -type f -name \*.pyc -execdir rm -v {} \;
