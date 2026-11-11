#!/data/data/com.termux/files/usr/bin/zsh

emulate -L zsh
setopt pipe_fail

# ---------- fetch ----------
local -a lines
lines=(${(f)"$(apt list --upgradable 2>/dev/null)"})

# ---------- filter ----------
local -a pkgs
local line name
for line in $lines; do
    [[ $line == Listing* || -z $line ]] && continue
    name=${line%%/*}                # strip "/repo version arch ..."
    [[ -z $name || $name == "$line" ]] && continue
    pkgs+=("$name")
done

# ---------- output ----------
if (( ${#pkgs} == 0 )); then
    print "No upgradable packages."
    return 0 2>/dev/null || exit 0
fi

for name in $pkgs; do
    printf '   - %s\n' "$name"
done
