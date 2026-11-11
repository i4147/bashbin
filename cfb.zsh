#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
fd -e c -e h -e cpp -e hpp -e cc -e hh -e cxx -e hxx --batch-size=12 -X clang-format -i --verbose {}
