#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
DAT_PATH="${DAT_PATH:-$PREFIX/share/xray}"
JSON_PATH="${JSON_PATH:-$PREFIX/etc/xray}"
LOG_PATH="${LOG_PATH:-$PREFIX/var/log/xray}"
BIN_PATH="${BIN_PATH:-$PREFIX/bin}"
SERVICE_DIR="${SERVICE_DIR:-$PREFIX/var/service/xray}"
XRAY_IS_INSTALLED_BEFORE_RUNNING_SCRIPT='0'
if [[ -f "$BIN_PATH/xray" ]]; then
	XRAY_IS_INSTALLED_BEFORE_RUNNING_SCRIPT='1'
fi
CURRENT_VERSION=''
RELEASE_LATEST=''
PRE_RELEASE_LATEST=''
INSTALL_VERSION=''
INSTALL='0'
INSTALL_GEODATA='0'
REMOVE='0'
HELP='0'
CHECK='0'
FORCE='0'
BETA='0'
NO_GEODATA='0'
NO_LOGFILES='0'
REINSTALL='0'
SPECIFIED_VERSION=''
LOCAL_FILE=''
PROXY=''
PURGE='0'
XRAY_RUNNING='0'
GEODATA='0'
CONFIG_NEW='0'
LOG='0'
SERVICE='0'
curl() {
	$(whence -p curl) -L -q --retry 5 --retry-delay 10 --retry-max-time 60 "$@"
}
identify_the_operating_system_and_architecture() {
	if [[ "$(uname)" != 'Linux' ]]; then
		echo "error: This operating system is not supported."
		return 1
	fi
	case "$(uname -m)" in
	'i386' | 'i686')
		MACHINE='32'
		;;
	'amd64' | 'x86_64')
		MACHINE='64'
		;;
	'armv7' | 'armv7l' | 'armv8l')
		MACHINE='arm32-v7a'
		;;
	'aarch64' | 'armv8' | 'arm64')
		MACHINE='arm64-v8a'
		;;
	'riscv64')
		MACHINE='riscv64'
		;;
	*)
		echo "error: The architecture is not supported."
		return 1
		;;
	esac
	if [[ -n "$(whence -p pkg)" ]]; then
		PACKAGE_MANAGEMENT_INSTALL='pkg install -y'
		PACKAGE_MANAGEMENT_REMOVE='pkg uninstall -y'
		package_provide_tput='ncurses-utils'
	else
		echo "error: This script is for Termux only. pkg not found."
		return 1
	fi
}
judgment_parameters() {
	local local_install='0'
	local temp_version='0'
	while [[ "$#" -gt '0' ]]; do
		case "$1" in
		'install')
			INSTALL='1'
			;;
		'install-geodata')
			INSTALL_GEODATA='1'
			;;
		'remove')
			REMOVE='1'
			;;
		'help')
			HELP='1'
			;;
		'check')
			CHECK='1'
			;;
		'--without-geodata')
			NO_GEODATA='1'
			;;
		'--without-logfiles')
			NO_LOGFILES='1'
			;;
		'--purge')
			PURGE='1'
			;;
		'--version')
			if [[ -z "$2" ]]; then
				echo "error: Please specify the correct version."
				return 1
			fi
			temp_version='1'
			SPECIFIED_VERSION="$2"
			shift
			;;
		'-f' | '--force')
			FORCE='1'
			;;
		'--beta')
			BETA='1'
			;;
		'-l' | '--local')
			local_install='1'
			if [[ -z "$2" ]]; then
				echo "error: Please specify the correct local file."
				return 1
			fi
			LOCAL_FILE="$2"
			shift
			;;
		'-p' | '--proxy')
			if [[ -z "$2" ]]; then
				echo "error: Please specify the proxy server address."
				return 1
			fi
			PROXY="$2"
			shift
			;;
		'--reinstall')
			REINSTALL='1'
			;;
		*)
			echo "$0: unknown option -- -"
			return 1
			;;
		esac
		shift
	done
	if ((INSTALL + INSTALL_GEODATA + HELP + CHECK + REMOVE == 0)); then
		INSTALL='1'
	elif ((INSTALL + INSTALL_GEODATA + HELP + CHECK + REMOVE > 1)); then
		echo 'You can only choose one action.'
		return 1
	fi
	if [[ "$INSTALL" -eq '1' ]] && ((temp_version + local_install + REINSTALL + BETA > 1)); then
		echo "--version,--reinstall,--beta and --local can't be used together."
		return 1
	fi
}
install_software() {
	package_name="$1"
	file_to_detect="$2"
	whence -p "$file_to_detect" >/dev/null 2>&1 && return
	if ${PACKAGE_MANAGEMENT_INSTALL} "$package_name" >/dev/null 2>&1; then
		echo "info: $package_name is installed."
	else
		echo "error: Installation of $package_name failed, please check your network."
		exit 1
	fi
}
get_current_version() {
	if [[ -f "$BIN_PATH/xray" ]]; then
		CURRENT_VERSION="$($BIN_PATH/xray -version | awk 'NR==1 {print $2}')"
		CURRENT_VERSION="v${CURRENT_VERSION#v}"
	else
		CURRENT_VERSION=""
	fi
}
get_latest_version() {
	local tmp_file
	tmp_file="$(mktemp)"
	local url='https://api.github.com/repos/XTLS/Xray-core/releases/latest'
	if curl -x "${PROXY}" -sSfLo "$tmp_file" -H "Accept: application/vnd.github.v3+json" "$url"; then
		echo "get release list success"
	else
		rm "$tmp_file"
		echo 'error: Failed to get release list, please check your network.'
		exit 1
	fi
	RELEASE_LATEST="$(sed 'y/,/\n/' "$tmp_file" | grep 'tag_name' | awk -F '"' '{print $4}')"
	if [[ -z "$RELEASE_LATEST" ]]; then
		if grep -q "API rate limit exceeded" "$tmp_file"; then
			echo "error: github API rate limit exceeded"
		else
			echo "error: Failed to get the latest release version."
			echo "Welcome bug report:https://github.com/XTLS/Xray-install/issues"
		fi
		rm "$tmp_file"
		exit 1
	fi
	rm "$tmp_file"
	RELEASE_LATEST="v${RELEASE_LATEST#v}"
	url='https://api.github.com/repos/XTLS/Xray-core/releases'
	if curl -x "${PROXY}" -sSfLo "$tmp_file" -H "Accept: application/vnd.github.v3+json" "$url"; then
		echo "get release list success"
	else
		rm "$tmp_file"
		echo 'error: Failed to get release list, please check your network.'
		exit 1
	fi
	local -a releases_list
	releases_list=( "${(@f)$(sed 'y/,/\n/' "$tmp_file" | grep 'tag_name' | awk -F '"' '{print $4}')}" )
	if (( ${#releases_list[@]} == 0 )); then
		if grep -q "API rate limit exceeded" "$tmp_file"; then
			echo "error: github API rate limit exceeded"
		else
			echo "error: Failed to get the latest release version."
			echo "Welcome bug report:https://github.com/XTLS/Xray-install/issues"
		fi
		rm "$tmp_file"
		exit 1
	fi
	local release url_zip
	for release in "${releases_list[@]}"; do
		release="v${release#v}"
		url_zip="https://github.com/XTLS/Xray-core/releases/download/${release}/Xray-linux-$MACHINE.zip"
		if grep -q "$url_zip" "$tmp_file"; then
			PRE_RELEASE_LATEST="$release"
			break
		fi
	done
	rm "$tmp_file"
}
version_gt() {
	test "$(echo -e "$1\\n$2" | sort -V | head -n 1)" != "$1"
}
download_xray() {
	local DOWNLOAD_LINK="https://github.com/XTLS/Xray-core/releases/download/${INSTALL_VERSION}/Xray-linux-${MACHINE}.zip"
	echo "Downloading Xray archive: $DOWNLOAD_LINK"
	if curl -f -x "${PROXY}" -R -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK"; then
		echo "ok."
	else
		echo 'error: Download failed! Please check your network or try again.'
		return 1
	fi
	echo "Downloading verification file for Xray archive: ${DOWNLOAD_LINK}.dgst"
	if curl -f -x "${PROXY}" -sSR -H 'Cache-Control: no-cache' -o "${ZIP_FILE}.dgst" "${DOWNLOAD_LINK}.dgst"; then
		echo "ok."
	else
		echo 'error: Download failed! Please check your network or try again.'
		return 1
	fi
	if grep 'Not Found' "${ZIP_FILE}.dgst"; then
		echo 'error: This version does not support verification. Please replace with another version.'
		return 1
	fi
	CHECKSUM=$(awk -F '= ' '/256=/ {print $2}' "${ZIP_FILE}.dgst")
	LOCALSUM=$(sha256sum "$ZIP_FILE" | awk '{printf $1}')
	if [[ "$CHECKSUM" != "$LOCALSUM" ]]; then
		echo 'error: SHA256 check failed! Please check your network or try again.'
		return 1
	fi
}
decompression() {
	if ! unzip -q "$1" -d "$TMP_DIRECTORY"; then
		echo 'error: Xray decompression failed.'
		rm -r "$TMP_DIRECTORY"
		echo "removed: $TMP_DIRECTORY"
		exit 1
	fi
	echo "info: Extract the Xray package to $TMP_DIRECTORY and prepare it for installation."
}
install_file() {
	NAME="$1"
	if [[ "$NAME" == 'xray' ]]; then
		install -m 755 "${TMP_DIRECTORY}/$NAME" "$BIN_PATH/$NAME"
	elif [[ "$NAME" == 'geoip.dat' ]] || [[ "$NAME" == 'geosite.dat' ]]; then
		install -m 644 "${TMP_DIRECTORY}/$NAME" "${DAT_PATH}/$NAME"
	fi
}
install_xray() {
	install_file xray
	if [[ "$NO_GEODATA" -eq '0' ]] && [[ ! -f "${DAT_PATH}/.undat" ]]; then
		mkdir -p "$DAT_PATH"
		install_file geoip.dat
		install_file geosite.dat
		GEODATA='1'
	fi
	if [[ ! -d "$JSON_PATH" ]]; then
		mkdir -p "$JSON_PATH"
		echo "{}" >"${JSON_PATH}/config.json"
		CONFIG_NEW='1'
	fi
	if [[ "$NO_LOGFILES" -eq '0' ]]; then
		if [[ ! -d "$LOG_PATH" ]]; then
			mkdir -p "$LOG_PATH"
			touch "$LOG_PATH/access.log" "$LOG_PATH/error.log"
			chmod 600 "$LOG_PATH/access.log" "$LOG_PATH/error.log"
			LOG='1'
		fi
	fi
}
install_startup_service_file() {
	if ! whence -p sv >/dev/null 2>&1; then
		${PACKAGE_MANAGEMENT_INSTALL} termux-services >/dev/null 2>&1 || true
	fi
	mkdir -p "$SERVICE_DIR/log" "$LOG_PATH"
	cat >"$SERVICE_DIR/run" <<EOF
#!/data/data/com.termux/files/usr/bin/sh
exec xray run -config $JSON_PATH/config.json 2>&1
EOF
	cat >"$SERVICE_DIR/log/run" <<EOF
#!/data/data/com.termux/files/usr/bin/sh
exec svlogd -tt $LOG_PATH
EOF
	chmod +x "$SERVICE_DIR/run" "$SERVICE_DIR/log/run"
	if command -v sv-enable >/dev/null 2>&1; then
		sv-enable xray 2>/dev/null || true
	fi
	SERVICE='1'
}
start_xray() {
	if command -v sv >/dev/null 2>&1 && [[ -d "$SERVICE_DIR" ]]; then
		sv up xray 2>/dev/null || true
		sleep 1
		if sv status xray 2>/dev/null | grep -q '^run:'; then
			echo 'info: Start the Xray service.'
			return
		fi
	fi
	nohup xray run -config "$JSON_PATH/config.json" >/dev/null 2>&1 &
	sleep 1
	if pgrep -f 'xray run' >/dev/null 2>&1; then
		echo 'info: Start the Xray service.'
	else
		echo 'error: Failed to start Xray service.'
		exit 1
	fi
}
stop_xray() {
	if command -v sv >/dev/null 2>&1 && [[ -d "$SERVICE_DIR" ]]; then
		sv down xray 2>/dev/null || true
	fi
	pkill -f 'xray run' 2>/dev/null || true
	echo 'info: Stop the Xray service.'
}
install_geodata() {
	download_geodata() {
		if ! curl -x "${PROXY}" -R -H 'Cache-Control: no-cache' -o "${dir_tmp}/${2}" "${1}"; then
			echo 'error: Download failed! Please check your network or try again.'
			exit 1
		fi
		if ! curl -x "${PROXY}" -R -H 'Cache-Control: no-cache' -o "${dir_tmp}/${2}.sha256sum" "${1}.sha256sum"; then
			echo 'error: Download failed! Please check your network or try again.'
			exit 1
		fi
	}
	local download_link_geoip="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
	local download_link_geosite="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
	local file_ip='geoip.dat'
	local file_dlc='geosite.dat'
	local file_site='geosite.dat'
	local dir_tmp
	dir_tmp="$(mktemp -d)"
	[[ "$XRAY_IS_INSTALLED_BEFORE_RUNNING_SCRIPT" -eq '0' ]] && echo "warning: Xray was not installed"
	download_geodata $download_link_geoip $file_ip
	download_geodata $download_link_geosite $file_dlc
	cd "${dir_tmp}" || exit
	for i in "${dir_tmp}"/*.sha256sum; do
		if ! sha256sum -c "${i}"; then
			echo 'error: Check failed! Please check your network or try again.'
			exit 1
		fi
	done
	cd - >/dev/null || exit 1
	mkdir -p "$DAT_PATH"
	install -m 644 "${dir_tmp}"/${file_dlc} "${DAT_PATH}"/${file_site}
	install -m 644 "${dir_tmp}"/${file_ip} "${DAT_PATH}"/${file_ip}
	rm -r "${dir_tmp}"
	exit 0
}
check_update() {
	if [[ "$XRAY_IS_INSTALLED_BEFORE_RUNNING_SCRIPT" -eq '1' ]]; then
		get_current_version
		echo "info: The current version of Xray is ${CURRENT_VERSION}."
	else
		echo 'warning: Xray is not installed.'
	fi
	get_latest_version
	echo "info: The latest release version of Xray is ${RELEASE_LATEST}."
	echo "info: The latest pre-release/release version of Xray is ${PRE_RELEASE_LATEST}."
	exit 0
}
remove_xray() {
	if [[ -f "$BIN_PATH/xray" ]]; then
		if pgrep -f 'xray run' >/dev/null 2>&1; then
			stop_xray
		fi
		local delete_files=("$BIN_PATH/xray")
		[[ -d "$DAT_PATH" ]] && delete_files+=("$DAT_PATH")
		[[ -d "$SERVICE_DIR" ]] && delete_files+=("$SERVICE_DIR")
		if [[ "$PURGE" -eq '1' ]]; then
			delete_files+=("$JSON_PATH")
			[[ -d "$LOG_PATH" ]] && delete_files+=("$LOG_PATH")
		fi
		if command -v sv-disable >/dev/null 2>&1; then
			sv-disable xray 2>/dev/null || true
		fi
		if ! (rm -r "${delete_files[@]}"); then
			echo 'error: Failed to remove Xray.'
			exit 1
		else
			for deleted_path in "${delete_files[@]}"; do
				echo "removed: $deleted_path"
			done
			echo "You may need to execute a command to remove dependent software: $PACKAGE_MANAGEMENT_REMOVE curl unzip"
			echo 'info: Xray has been removed.'
			if [[ "$PURGE" -eq '0' ]]; then
				echo 'info: If necessary, manually delete the configuration and log files.'
				echo "info: e.g., $JSON_PATH and $LOG_PATH ..."
			fi
			exit 0
		fi
	else
		echo 'error: Xray is not installed.'
		exit 1
	fi
}
show_help() {
	echo "usage: $0 ACTION [OPTION]..."
	echo
	echo 'ACTION:'
	echo '  install                   Install/Update Xray'
	echo '  install-geodata           Install/Update geoip.dat and geosite.dat only'
	echo '  remove                    Remove Xray'
	echo '  help                      Show help'
	echo '  check                     Check if Xray can be updated'
	echo 'If no action is specified, then install will be selected'
	echo
	echo 'OPTION:'
	echo '  install:'
	echo '    --version                 Install the specified version of Xray, e.g., --version v1.0.0'
	echo '    -f, --force               Force install even though the versions are same'
	echo '    --beta                    Install the pre-release version if it is exist'
	echo '    -l, --local               Install Xray from a local file'
	echo '    -p, --proxy               Download through a proxy server'
	echo '    --reinstall               Reinstall current Xray version'
	echo '    --without-geodata         Don'"'"'t install/update geoip.dat and geosite.dat'
	echo '    --without-logfiles        Don'"'"'t install log directory'
	echo '  install-geodata:'
	echo '    -p, --proxy               Download through a proxy server'
	echo '  remove:'
	echo '    --purge                   Remove all the Xray files, include logs, configs, etc'
	echo '  check:'
	echo '    -p, --proxy               Check new version through a proxy server'
	exit 0
}
main() {
	identify_the_operating_system_and_architecture || return 1
	judgment_parameters "$@" || return 1
	install_software "$package_provide_tput" 'tput'
	install_software 'procps' 'pgrep'
	red=$(tput setaf 1)
	green=$(tput setaf 2)
	aoi=$(tput setaf 6)
	reset=$(tput sgr0)
	[[ "$HELP" -eq '1' ]] && show_help
	[[ "$CHECK" -eq '1' ]] && check_update
	[[ "$REMOVE" -eq '1' ]] && remove_xray
	[[ "$INSTALL_GEODATA" -eq '1' ]] && install_geodata
	TMP_DIRECTORY="$(mktemp -d)"
	ZIP_FILE="${TMP_DIRECTORY}/Xray-linux-$MACHINE.zip"
	if [[ -n "$LOCAL_FILE" ]]; then
		echo 'warn: Install Xray from a local file, but still need to make sure the network is available.'
		echo -n 'warn: Please make sure the file is valid because we cannot confirm it. (Press any key) ...'
		read -r
		install_software 'unzip' 'unzip'
		decompression "$LOCAL_FILE"
	else
		get_current_version
		if [[ "$REINSTALL" -eq '1' ]]; then
			if [[ -z "$CURRENT_VERSION" ]]; then
				echo "error: Xray is not installed"
				exit 1
			fi
			INSTALL_VERSION="$CURRENT_VERSION"
			echo "info: Reinstalling Xray $CURRENT_VERSION"
		elif [[ -n "$SPECIFIED_VERSION" ]]; then
			SPECIFIED_VERSION="v${SPECIFIED_VERSION#v}"
			if [[ "$CURRENT_VERSION" == "$SPECIFIED_VERSION" ]] && [[ "$FORCE" -eq '0' ]]; then
				echo "info: The current version is same as the specified version. The version is ${CURRENT_VERSION}."
				exit 0
			fi
			INSTALL_VERSION="$SPECIFIED_VERSION"
			echo "info: Installing specified Xray version $INSTALL_VERSION for $(uname -m)"
		else
			install_software 'curl' 'curl'
			get_latest_version
			if [[ "$BETA" -eq '0' ]]; then
				INSTALL_VERSION="$RELEASE_LATEST"
			else
				INSTALL_VERSION="$PRE_RELEASE_LATEST"
			fi
			if ! version_gt "$INSTALL_VERSION" "$CURRENT_VERSION" && [[ "$FORCE" -eq '0' ]]; then
				echo "info: No new version. The current version of Xray is ${CURRENT_VERSION}."
				exit 0
			fi
			echo "info: Installing Xray $INSTALL_VERSION for $(uname -m)"
		fi
		install_software 'curl' 'curl'
		install_software 'unzip' 'unzip'
		if ! download_xray; then
			rm -r "$TMP_DIRECTORY"
			echo "removed: $TMP_DIRECTORY"
			exit 1
		fi
		decompression "$ZIP_FILE"
	fi
	if pgrep -f 'xray run' >/dev/null 2>&1; then
		stop_xray
		XRAY_RUNNING='1'
	fi
	install_xray
	install_startup_service_file
	echo 'installed: '"$BIN_PATH"'/xray'
	if [[ "$GEODATA" -eq '1' ]]; then
		echo "installed: ${DAT_PATH}/geoip.dat"
		echo "installed: ${DAT_PATH}/geosite.dat"
	fi
	if [[ "$CONFIG_NEW" -eq '1' ]]; then
		echo "installed: ${JSON_PATH}/config.json"
	fi
	if [[ "$LOG" -eq '1' ]]; then
		echo "installed: ${LOG_PATH}/"
		echo "installed: ${LOG_PATH}/access.log"
		echo "installed: ${LOG_PATH}/error.log"
	fi
	if [[ "$SERVICE" -eq '1' ]]; then
		echo "installed: ${SERVICE_DIR}/run"
		echo "installed: ${SERVICE_DIR}/log/run"
	fi
	rm -r "$TMP_DIRECTORY"
	echo "removed: $TMP_DIRECTORY"
	get_current_version
	echo "info: Xray $CURRENT_VERSION is installed."
	echo "You may need to execute a command to remove dependent software: $PACKAGE_MANAGEMENT_REMOVE curl unzip"
	if [[ "$XRAY_IS_INSTALLED_BEFORE_RUNNING_SCRIPT" -eq '1' ]] && [[ "$FORCE" -eq '0' ]] && [[ "$REINSTALL" -eq '0' ]]; then
		[[ "$XRAY_RUNNING" -eq '1' ]] && start_xray
	else
		start_xray
	fi
}
main "$@"
