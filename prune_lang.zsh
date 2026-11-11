#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
# Keep only the selected language folders, delete the rest.
set -euo pipefail
KEEP=(fa ar tr de en ja zh ru ko)
# Build an associative array for O(1) lookup
typeset -A keep_map
for k in "${KEEP[@]}"; do
	keep_map["$k"]=1
done
# Sanity: ensure the script runs in the directory containing the folders
setopt NULL_GLOB
dirs=(*/)
if ((${#dirs[@]} == 0)); then
	echo "No subdirectories found in $(pwd)" >&2
	exit 1
fi
echo "Keeping: ${KEEP[*]}"
echo
for d in "${dirs[@]}"; do
	name="${d%/}"
	if [[ -n "${keep_map[$name]:-}" ]]; then
		echo "KEEP   $name"
	else
		echo "DELETE $name"
		rm -rf -- "$name"
	fi
done
echo
echo "Done."
