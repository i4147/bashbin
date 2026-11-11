#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
# Wrapper that pretends this 32-bit ARMv8 userspace is plain armv7,
# so tools like maturin stop choking on "armv8l".

REAL_UNAME=/data/data/com.termux/files/usr/bin/uname

# If no args, uname defaults to -s
if [ $# -eq 0 ]; then
    set -- -s
fi

out=$("$REAL_UNAME" "$@")
uname_status=$?

# Replace armv8l (and armv8b just in case) with armv7l in the output.
printf '%s\n' "$out" | sed -e 's/armv8l/armv7l/g' -e 's/armv8b/armv7l/g'

exit $uname_status
