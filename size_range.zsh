#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
#fd -e "$@" -x stat -c '%s %n' {} | sort -n | sed -n '1p;$p'
fd -e "$@" -x stat -c '%s %n' {} | sort -n > $PREFIX/tmp/sizes.txt

echo "=== 5 smallest ==="
head -n 5 $PREFIX/tmp/sizes.txt | while read s f; do printf '%8s  %s\n' "$(numfmt --to=iec $s)" "$f"; done

echo "=== 5 biggest ==="
tail -n 5 $PREFIX/tmp/sizes.txt | tac | while read s f; do printf '%8s  %s\n' "$(numfmt --to=iec $s)" "$f"; done
