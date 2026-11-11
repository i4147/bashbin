#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
find ~/.local/share/nvim/lazy -maxdepth 1 -mindepth 1 -type d -exec sh -c '
  for d; do
    [ -d "$d/.git" ] || continue
    git -C "$d" checkout -- . && git -C "$d" clean -fd
  done
' sh {} +
