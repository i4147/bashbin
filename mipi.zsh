#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
MP=mypy
ls *.py | xargs -P 8 -I{} sh -c ''"$MP"' --ignore-missing-imports --no-error-summary --no-color-output --cache-dir=~/.cache/mypyc-$$ "{}" 2>&1' >~/mypy_all.txt
wc -l <~/mypy_all.txt
grep -c 'error:' ~/mypy_all.txt
grep -o '\[[a-z-]*\]$' ~/mypy_all.txt | sort | uniq -c | sort -rn
