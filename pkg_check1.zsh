#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
dpkg -S $PREFIX/bin/build* 2>/dev/null
grep -r "bin/build" $PREFIX/var/lib/dpkg/info/*.list
