#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
objcopy --only-keep-debug "$@" "$@".debug
strip --strip-debug "$@"
objcopy --add-gnu-debuglink="$@".debug "$@"
