#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH

set -euo pipefail

OLD_USERNAME="${OLD_USERNAME:-iho147}"
OLD_EMAIL="${OLD_EMAIL:-isaacaunegh@gmail.com}"
NEW_USERNAME="${NEW_USERNAME:-i4147}"
NEW_EMAIL="${NEW_EMAIL:-yesnacoc@gmail.com}"

HOME_DIR="${HOME_DIR:-$HOME}"
SSH_DIR="${SSH_DIR:-$HOME/.ssh}"
NEW_KEY_PATH="${NEW_KEY_PATH:-$HOME/.ssh/id_ed25519_github_new}"

APPLY=0
SKIP_SSH=0
SKIP_FILES=0

LOG_FILE="github_identity_migrate.log"
MAX_FILE_SIZE=$((5 * 1024 * 1024))

TEXT_EXTENSIONS=(
	"py" "toml" "cfg" "ini" "json" "md" "yml" "yaml"
	"txt" "rst" "env" "sh" "bash" "zshrc" "gitconfig"
	"gitmodules" "npmrc" "yarnrc"
)

TEXT_FILENAMES=(
	"setup.py" "pyproject.toml" "package.json" "config"
	".gitconfig" "README.md" "README" ".npmrc" "Makefile"
)

SKIP_DIRS=(
	"node_modules" ".venv" "venv" "env" "pycache" "dist"
	"build" ".tox" "site-packages" ".git" ".mypy_cache"
	".pytest_cache" ".idea" ".vscode" "target" ".cache"
)

RED=""
GREEN=""
YELLOW=""
BLUE=""
BOLD=""
RESET=""

if [[ -t 1 ]]; then
	RED=$'\033[91m'
	GREEN=$'\033[92m'
	YELLOW=$'\033[93m'
	BLUE=$'\033[94m'
	BOLD=$'\033[1m'
	RESET=$'\033[0m'
fi

log() {
	local msg="$1"
	echo "$msg"
	echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $msg" >>"$LOG_FILE"
}

log_debug() {
	local msg="$1"
	echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $msg" >>"$LOG_FILE"
}

log_error() {
	local msg="$1"
	echo "${RED}${msg}${RESET}" >&2
	echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $msg" >>"$LOG_FILE"
}

color() {
	local c="$1"
	local text="$2"
	if [[ -t 1 ]]; then
		echo "${c}${text}${RESET}"
	else
		echo "$text"
	fi
}

usage() {
	cat <<EOF
Usage: $0 [options]

Options:
  --old-username NAME    Old GitHub username (default: $OLD_USERNAME)
  --old-email EMAIL      Old email (default: $OLD_EMAIL)
  --new-username NAME    New GitHub username (default: $NEW_USERNAME)
  --new-email EMAIL      New email (default: $NEW_EMAIL)
  --home DIR             Home directory to scan (default: \$HOME)
  --ssh-dir DIR          SSH directory (default: ~/.ssh)
  --new-key-path PATH    Path for new private key (default: ~/.ssh/id_ed25519_github_new)
  --apply                Actually write changes (default: dry-run)
  --skip-ssh             Skip SSH key generation/removal
  --skip-files           Skip home-directory file scan/replace
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--old-username)
		OLD_USERNAME="$2"
		shift 2
		;;
	--old-email)
		OLD_EMAIL="$2"
		shift 2
		;;
	--new-username)
		NEW_USERNAME="$2"
		shift 2
		;;
	--new-email)
		NEW_EMAIL="$2"
		shift 2
		;;
	--home)
		HOME_DIR="$2"
		shift 2
		;;
	--ssh-dir)
		SSH_DIR="$2"
		shift 2
		;;
	--new-key-path)
		NEW_KEY_PATH="$2"
		shift 2
		;;
	--apply)
		APPLY=1
		shift
		;;
	--skip-ssh)
		SKIP_SSH=1
		shift
		;;
	--skip-files)
		SKIP_FILES=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		log_error "Unknown option: $1"
		usage
		exit 1
		;;
	esac
done

should_skip_dir() {
	local dirname="$1"
	[[ "$dirname" == .git* ]] && return 0
	for d in "${SKIP_DIRS[@]}"; do
		[[ "$dirname" == "$d" ]] && return 0
	done
	return 1
}

matches_target_file() {
	local fname="$1"
	for f in "${TEXT_FILENAMES[@]}"; do
		[[ "$fname" == "$f" ]] && return 0
	done
	local ext="${fname##*.}"
	for e in "${TEXT_EXTENSIONS[@]}"; do
		[[ "$ext" == "$e" ]] && return 0
	done
	return 1
}

is_probably_text_file() {
	local file_path="$1"
	if head -c 1024 "$file_path" 2>/dev/null | grep -q $'\x00'; then
		return 1
	fi
	return 0
}

backup_file() {
	local file_path="$1"
	local ts
	ts=$(date '+%Y%m%d_%H%M%S')
	local backup_path="${file_path}.${ts}.bak"
	cp -p "$file_path" "$backup_path"
	echo "$backup_path"
}

update_global_git_config() {
	log "$(color "$BOLD" "=== Step 1: Global git config ===")"

	local current_name current_email
	current_name=$(git config --global --get user.name 2>/dev/null || true)
	current_email=$(git config --global --get user.email 2>/dev/null || true)

	log "Current global user.name : ${current_name:-(not set)}"
	log "Current global user.email: ${current_email:-(not set)}"
	log "New global user.name      -> $NEW_USERNAME"
	log "New global user.email     -> $NEW_EMAIL"

	if [[ $APPLY -eq 0 ]]; then
		log "$(color "$YELLOW" "[DRY-RUN] Would update global git config.")"
		return
	fi

	git config --global user.name "$NEW_USERNAME"
	git config --global user.email "$NEW_EMAIL"
	log "$(color "$GREEN" "[APPLIED] Global git config updated.")"
}

find_local_git_configs() {
	local scan_root="$1"
	local prune_expr=()
	for d in "${SKIP_DIRS[@]}"; do
		prune_expr+=(-name "$d" -o)
	done
	prune_expr+=(-name ".git*" -o)
	find "$scan_root" \( "${prune_expr[@]}" -false \) -prune -o -type d -name ".git" -print 2>/dev/null | while read -r gitdir; do
		if [[ -f "$gitdir/config" ]]; then
			echo "$gitdir/config"
		fi
	done
}

update_local_git_configs() {
	log "$(color "$BOLD" "=== Step 1b: Local repo .git/config files ===")"

	local configs
	configs=$(find_local_git_configs "$HOME_DIR" || true)

	local count=0
	local changed=0
	local changed_list=()

	while IFS= read -r cfg; do
		[[ -z "$cfg" ]] && continue
		count=$((count + 1))

		local content
		content=$(cat "$cfg" 2>/dev/null || true)

		if ! grep -qF "$OLD_USERNAME" <<<"$content" && ! grep -qF "$OLD_EMAIL" <<<"$content"; then
			continue
		fi

		changed=$((changed + 1))
		changed_list+=("$cfg")
		log "  Would update: $cfg"

		if [[ $APPLY -eq 1 ]]; then
			local backup_path
			backup_path=$(backup_file "$cfg")
			sed -i "s|${OLD_USERNAME}|${NEW_USERNAME}|g; s|${OLD_EMAIL}|${NEW_EMAIL}|g" "$cfg"
			log "$(color "$GREEN" "    [APPLIED] Updated (backup: $backup_path)")"
		fi
	done <<<"$configs"

	log "Found $count local repo git config file(s)."

	if [[ $changed -eq 0 ]]; then
		log "No local repo configs reference the old identity."
	elif [[ $APPLY -eq 0 ]]; then
		log "$(color "$YELLOW" "[DRY-RUN] $changed local config file(s) would be updated.")"
	fi
}

scan_files() {
	local scan_root="$1"
	local prune_expr=()
	for d in "${SKIP_DIRS[@]}"; do
		prune_expr+=(-name "$d" -o)
	done
	prune_expr+=(-name ".git*" -o)
	find "$scan_root" \( "${prune_expr[@]}" -false \) -prune -o -type f -print 2>/dev/null
}

preview_and_replace() {
	log "$(color "$BOLD" "=== Step 2: Scanning files under home folder ===")"
	log "Home directory: $HOME_DIR"

	local candidates
	candidates=$(scan_files "$HOME_DIR" || true)

	local total_candidates=0
	while IFS= read -r f; do
		[[ -z "$f" ]] && continue
		if matches_target_file "$(basename "$f")"; then
			total_candidates=$((total_candidates + 1))
		fi
	done <<<"$candidates"

	log "Scanning $total_candidates candidate file(s)..."

	local to_change=()
	local to_change_new_content=()

	while IFS= read -r fpath; do
		[[ -z "$fpath" ]] && continue

		if ! matches_target_file "$(basename "$fpath")"; then
			continue
		fi

		local size
		size=$(stat -c%s "$fpath" 2>/dev/null || stat -f%z "$fpath" 2>/dev/null || echo 0)
		if [[ "$size" -gt "$MAX_FILE_SIZE" ]]; then
			continue
		fi

		if ! is_probably_text_file "$fpath"; then
			continue
		fi

		if ! grep -qF "$OLD_USERNAME" "$fpath" 2>/dev/null && ! grep -qF "$OLD_EMAIL" "$fpath" 2>/dev/null; then
			continue
		fi

		to_change+=("$fpath")
	done <<<"$candidates"

	if [[ ${#to_change[@]} -eq 0 ]]; then
		log "$(color "$GREEN" "No files contain traces of the old identity.")"
		return
	fi

	log "$(color "$YELLOW" "Found ${#to_change[@]} file(s) that would change:")"

	for fpath in "${to_change[@]}"; do
		log "$(color "$BLUE" "  $fpath")"
		local diff_output
		diff_output=$(diff <(sed "s|${OLD_USERNAME}|${NEW_USERNAME}|g; s|${OLD_EMAIL}|${NEW_EMAIL}|g" "$fpath") "$fpath" 2>/dev/null | head -20 || true)
		while IFS= read -r line; do
			[[ -z "$line" ]] && continue
			if [[ "$line" == "<"* ]]; then
				log "$(color "$GREEN" "      + ${line#< }")"
			elif [[ "$line" == ">"* ]]; then
				log "$(color "$RED" "      - ${line#> }")"
			fi
		done <<<"$diff_output"
	done

	if [[ $APPLY -eq 0 ]]; then
		log "$(color "$YELLOW" "[DRY-RUN] ${#to_change[@]} file(s) would be modified. Re-run with --apply to write changes.")"
		return
	fi

	printf '%s' "$(color "$BOLD" "Proceed to modify ${#to_change[@]} file(s) in-place? Backups (.bak) will be created. [y/N]: ")" >&2
	read -r confirm
	confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')

	if [[ "$confirm" != "y" ]]; then
		log "Aborted by user. No files were modified."
		return
	fi

	for fpath in "${to_change[@]}"; do
		local backup_path
		backup_path=$(backup_file "$fpath")
		sed -i "s|${OLD_USERNAME}|${NEW_USERNAME}|g; s|${OLD_EMAIL}|${NEW_EMAIL}|g" "$fpath"
		log "$(color "$GREEN" "[APPLIED] Updated $fpath (backup: $backup_path)")"
	done
}

create_new_ssh_key() {
	log "$(color "$BOLD" "=== Step 3: Create new SSH key ===")"
	log "Target key path: $NEW_KEY_PATH"
	log "Key type: ed25519, comment: $NEW_EMAIL"

	if [[ -f "$NEW_KEY_PATH" ]]; then
		log "$(color "$YELLOW" "Key already exists at $NEW_KEY_PATH. Skipping generation.")"
		return
	fi

	if [[ $APPLY -eq 0 ]]; then
		log "$(color "$YELLOW" "[DRY-RUN] Would run ssh-keygen to create a new key.")"
		return
	fi

	mkdir -p "$(dirname "$NEW_KEY_PATH")"

	local passphrase=""
	printf '%s' "Set a passphrase for the new SSH key? [y/N] (recommended): " >&2
	read -r use_passphrase
	use_passphrase=$(echo "$use_passphrase" | tr '[:upper:]' '[:lower:]')

	if [[ "$use_passphrase" == "y" ]]; then
		printf '%s' "Enter passphrase: " >&2
		read -r -s passphrase
		printf '\n' >&2
		echo
		local confirm_pass
		printf '%s' "Confirm passphrase: " >&2
		read -r -s confirm_pass
		printf '\n' >&2
		echo
		if [[ "$passphrase" != "$confirm_pass" ]]; then
			log_error "Passphrases do not match. Aborting SSH key creation."
			return
		fi
	fi

	if ssh-keygen -t ed25519 -C "$NEW_EMAIL" -f "$NEW_KEY_PATH" -N "$passphrase"; then
		log "$(color "$GREEN" "[APPLIED] New SSH key created at $NEW_KEY_PATH")"

		if [[ -f "${NEW_KEY_PATH}.pub" ]]; then
			log "$(color "$BOLD" "Your new PUBLIC key (add this to GitHub):")"
			log "$(color "$BLUE" "$(cat "${NEW_KEY_PATH}.pub")")"
			log "Add it at: https://github.com/settings/keys"
			echo
		fi

		local add_agent
		printf '%s' "Add new key to ssh-agent now? [y/N]: " >&2
		read -r add_agent
		add_agent=$(echo "$add_agent" | tr '[:upper:]' '[:lower:]')
		if [[ "$add_agent" == "y" ]]; then
			ssh-add "$NEW_KEY_PATH"
			log "$(color "$GREEN" "[APPLIED] Key added to ssh-agent.")"
		fi
	else
		log_error "ssh-keygen failed. See log for details."
	fi
}

find_old_ssh_keys() {
	if [[ ! -d "$SSH_DIR" ]]; then
		return
	fi

	for pub_file in "$SSH_DIR"/*.pub; do
		[[ -f "$pub_file" ]] || continue
		local content
		content=$(cat "$pub_file" 2>/dev/null || true)

		if grep -qF "$OLD_USERNAME" <<<"$content" || grep -qF "$OLD_EMAIL" <<<"$content"; then
			local priv_key="${pub_file%.pub}"
			if [[ -f "$priv_key" ]]; then
				echo "$pub_file|$priv_key"
			else
				echo "$pub_file|"
			fi
		fi
	done
}

remove_old_ssh_keys() {
	log "$(color "$BOLD" "=== Step 4: Find & remove old SSH keys ===")"
	log "SSH directory: $SSH_DIR"

	local matches
	matches=$(find_old_ssh_keys || true)

	if [[ -z "$matches" ]]; then
		log "$(color "$GREEN" "No old SSH public keys matching the previous identity were found.")"
		return
	fi

	local count=0
	while IFS='|' read -r pub priv; do
		[[ -z "$pub" ]] && continue
		count=$((count + 1))
		log "  Public : $pub"
		if [[ -n "$priv" ]]; then
			log "  Private: $priv"
		else
			log "  Private: (not found)"
		fi
	done <<<"$matches"

	log "$(color "$YELLOW" "Found $count old key pair(s):")"

	if [[ $APPLY -eq 0 ]]; then
		log "$(color "$YELLOW" "[DRY-RUN] Would remove the above key files.")"
		return
	fi

	local confirm
	printf '%s' "$(color "$BOLD" "Permanently delete these $count key pair(s)? [y/N]: ")" >&2
	read -r confirm
	confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')

	if [[ "$confirm" != "y" ]]; then
		log "Aborted by user. No SSH keys were deleted."
		return
	fi

	while IFS='|' read -r pub priv; do
		[[ -z "$pub" ]] && continue
		if [[ -n "$priv" && -f "$priv" ]]; then
			local bak
			bak=$(backup_file "$priv")
			rm -f "$priv"
			log "$(color "$GREEN" "[APPLIED] Removed private key $priv (backup: $bak)")"
		fi
		if [[ -f "$pub" ]]; then
			local bak
			bak=$(backup_file "$pub")
			rm -f "$pub"
			log "$(color "$GREEN" "[APPLIED] Removed public key  $pub (backup: $bak)")"
		fi
	done <<<"$matches"
}

main() {
	log "$(color "$BOLD" "GitHub Identity Migration Tool")"
	if [[ $APPLY -eq 1 ]]; then
		log "Mode: APPLY (changes will be written)"
	else
		log "Mode: DRY-RUN (no changes)"
	fi
	log "Old identity: $OLD_USERNAME "
	log "New identity: $NEW_USERNAME "
	log "Log file: $LOG_FILE"

	update_global_git_config
	update_local_git_configs

	if [[ $SKIP_FILES -eq 0 ]]; then
		preview_and_replace
	else
		log "$(color "$YELLOW" "=== Step 2: Skipped (--skip-files) ===")"
	fi

	if [[ $SKIP_SSH -eq 0 ]]; then
		create_new_ssh_key
		remove_old_ssh_keys
	else
		log "$(color "$YELLOW" "=== Steps 3/4: Skipped (--skip-ssh) ===")"
	fi

	log "$(color "$BOLD" "=== Done ===")"
	if [[ $APPLY -eq 0 ]]; then
		log "$(color "$YELLOW" "This was a dry-run. Re-run with --apply to perform the changes.")"
	else
		log "$(color "$YELLOW" "Remember the MANUAL steps: add new public key to GitHub, revoke old key, update credentials.")"
	fi
}

main
