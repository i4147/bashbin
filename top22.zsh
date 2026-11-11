#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
largest_file=$(
	python3 - <<'EOF'
import os
from pathlib import Path
start = Path(".").resolve()
largest = None
for p in start.rglob("*"):
    if p.is_file():
        try:
            s = p.stat().st_size
            if largest is None or s > largest[1]:
                largest = (p, s)
        except:
            continue
if largest:
    print(largest[0])
EOF
)
if [ -z "$largest_file" ]; then
	echo "No files found."
	exit 1
fi
echo "Largest file: $largest_file"
echo "Directory: $(dirname "$largest_file")"
cd "$(dirname "$largest_file")"
echo
echo "Directory changed to:"
pwd
