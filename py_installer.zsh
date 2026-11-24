#!/data/data/com.termux/files/usr/bin/bash
set -e

script=$1
shift

strip_ext() {
  if (( $# != 1 )); then
    print -u2 "Usage: strip_ext filename"
    return 2
  fi

  print -r -- "${1:r}"
}

name=${$(strip_ext "$script"):t}

#name=$(basename "$script" .py)
pyinstaller --clean --onefile --name "$name" "$script" "$@"
