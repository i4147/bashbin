#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH

set -euo pipefail
RUFF_BIN="${RUFF_BIN:-ruff}"
TEMP_DIR=""
CLEANUP_DONE=0
cleanup() {
	if [[ $CLEANUP_DONE -eq 0 ]]; then
		CLEANUP_DONE=1
		if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
			rm -rf "$TEMP_DIR"
		fi
	fi
}
trap cleanup EXIT INT TERM
process_file() {
	local input_file="$1"
	shift
	local ruff_args=("$@")
	if [[ ! -f "$input_file" ]]; then
		echo "Error: File not found: $input_file" >&2
		return 1
	fi
	if [[ -z "$TEMP_DIR" ]]; then
		TEMP_DIR=$(mktemp -d)
	fi
	local base_name=$(basename "$input_file")
	local temp_file="$TEMP_DIR/${base_name}.py"
	cp "$input_file" "$temp_file"
	if "$RUFF_BIN" format "${ruff_args[@]}" "$temp_file"; then
		cp "$temp_file" "$input_file"
		echo "Formatted: $input_file"
		return 0
	else
		echo "Error formatting: $input_file" >&2
		return 1
	fi
}
main() {
	local files=()
	local ruff_args=()
	local parse_files=0
	for arg in "$@"; do
		if [[ "$arg" == "--" ]]; then
			parse_files=1
			continue
		fi
		if [[ $parse_files -eq 1 ]]; then
			files+=("$arg")
		elif [[ "$arg" != -* ]]; then
			files+=("$arg")
		else
			ruff_args+=("$arg")
		fi
	done
	if [[ ${#files[@]} -eq 0 ]]; then
		echo "Usage: $0 [ruff options] <file1> [file2] ..." >&2
		echo "Options:" >&2
		echo "  --check    Check if files would be formatted without modifying them" >&2
		echo "  --diff     Show what changes would be made" >&2
		echo "  --quiet    Don't print filenames" >&2
		exit 1
	fi
	local exit_code=0
	for file in "${files[@]}"; do
		if ! process_file "$file" "${ruff_args[@]}"; then
			exit_code=1
		fi
	done
	exit $exit_code
}
main "$@"
