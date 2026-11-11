#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
unlink_recursive() {
	local target_dir="$1"
	for entry in "$target_dir"/* "$target_dir"/.[!.]* "$target_dir"/..?*; do
		case "$entry" in
		*'*'* | *'?'*) continue ;;
		esac
		unlink_recursive "$entry"
	done 2>/dev/null
	if rmdir "$target_dir" 2>/dev/null; then
		:
	elif unlink "$target_dir" 2>/dev/null; then
		:
	else
		:
	fi
}
for target in "$@"; do
	echo "Unlinking broken symlinks..."
	unlink_recursive "$target"
done
busybox rm "$@"
