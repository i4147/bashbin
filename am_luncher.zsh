#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
base=/system
export CLASSPATH=$base/framework/am.jar
exec am $base/bin com.android.commands.am.Am "$@"
