#!/bin/bash

# functions

function check_remote_host()
{
	# HOST
	if [ -z $1 ]; then
		return 1
	fi
	local CMD_TEST="$(ping -c1 $1 2>&1 | grep cannot)"
	if [ ! "$CMD_TEST" = "" ]; then
		return 1
	fi
	CMD_TEST="$(ping -c1 $1 2>&1 | grep sendto)"
	if [ ! "$CMD_TEST" = "" ]; then
		return 1
	fi
	return 0
}

function cmd_ssh()
{
	# HOST USER [PASS] [PORT]
	if [ -z $2 ]; then
		return 1
	fi
	local MY_HOST="$1"
	local MY_USER="$2"
	local MY_PASS=""
	if [ $3 ]; then
		MY_PASS="$3"
	fi
	local MY_PORT=""
	if [ $4 ]; then
		MY_PORT="$4"
	fi
	if [ ! "$MY_PORT" = "" ]; then
		echo "$(maybe_sshpass "$MY_PASS")ssh $MY_USER@$MY_HOST -p $MY_PORT"
		return 0
	else
		echo "$(maybe_sshpass "$MY_PASS")ssh $MY_USER@$MY_HOST"
		return 0
	fi
	return 1
}

function cmd_tmux()
{
	# CMD [SESSION] [SUDO]
	if [ -z "$1" ]; then
		return 1
	fi
	local STR_SESSION=""
	if [ $2 ]; then
		STR_SESSION=" -s ${2%%.*}"
	fi
	local STR_SUDO=""
	if [ $3 ] && [ "$3" = "sudo" ]; then
		STR_SUDO="$(maybe_sudo)"
	fi
	echo "${STR_SUDO}tmux new -d${STR_SESSION} \"$(escape_quotes "$1")\" > /dev/null 2>&1"
	return 0
}

function delete_macos_system_files()
{
	# DIR [SUDO]
	if [ -z "$1" ]; then
		return 1
	fi
	local STR_TEST="$(get_realpath "$1")"
	if [ ! -d "$STR_TEST" ]; then
		return 1
	fi
	local STR_SUDO=""
	if [ $2 ] && [ "$2" = "sudo" ]; then
		STR_SUDO="$(maybe_sudo)"
	fi
	${STR_SUDO}find "$STR_TEST" -type f -name "._*" -o -name "*DS_Store*" | while read STR_FILE; do ${STR_SUDO}rm -f "$STR_FILE"; done > /dev/null 2>&1
	${STR_SUDO}find "$STR_TEST" -type d -name ".fseventsd" -o -name ".Spotlight-V100" | while read STR_FILE; do ${STR_SUDO}rm -Rf "$STR_FILE"; done > /dev/null 2>&1
	return 0
}

function dir_has_files()
{
	# DIR
	if [ -z "$1" ]; then
		return 1
	fi
	local STR_TEST="$(get_realpath "$1")"
	if ! dir_not_empty "$STR_TEST"; then
		return 1
	fi
	if [ "$(find "$STR_TEST" -maxdepth 1 -type f -name '*.*')" = "" ]; then
		return 1
	fi
	return 0
}

function dir_not_empty()
{
	# DIR
	if [ -z "$1" ]; then
		return 1
	fi
	local STR_TEST="$(get_realpath "$1")"
	if [ ! -d "$STR_TEST" ]; then
		return 1
	fi
	if [ "$(ls -A "$STR_TEST")" = "" ]; then
		return 1
	fi
	return 0
}

function escape_quotes()
{
	# STRING
	local STR_TEST="$*"
	if [[ "$STR_TEST" = *\"* ]]; then
		STR_TEST="${STR_TEST//\"/\\\"}"
	fi
	echo "$STR_TEST"
	return 0
}

function escape_slashes()
{
	# STRING
	local STR_TEST="$*"
	if [[ "$STR_TEST" = */* ]]; then
		STR_TEST="${STR_TEST//\//\\/}"
	fi
	echo "$STR_TEST"
	return 0
}

function escape_spaces()
{
	# STRING
	local STR_TEST="$*"
	if [[ "$STR_TEST" = *\ * ]]; then
		STR_TEST="${STR_TEST// /\\ }"
	fi
	echo "$STR_TEST"
	return 0
}

function file_add_line()
{
    # FILE STRING [SUDO] [BACKUP]
	if [ -z "$2" ]; then
        return 1
    fi
    if [ ! -e "$1" ]; then
        return 1
    fi
	if file_contains_line "$1" "$2"; then
		return 0
	fi
	# uncomment
	if file_contains_line "$1" "#$2"; then
		local ARG_SUDO=""
		if [ $3 ]; then
			ARG_SUDO="$3"
		fi
		local ARG_BACKUP=""
		if [ $4 ]; then
			ARG_BACKUP="$4"
		fi
		if file_replace_line_first "$1" "#($2)" "\1" "$ARG_SUDO" "$ARG_BACKUP"; then
			return 0
		fi
	fi
	local STR_SUDO=""
	if [ $3 ] && [ "$3" = "sudo" ]; then
		STR_SUDO="$(maybe_sudo)"
	fi
	if [ $4 ]; then
		${STR_SUDO}cp -f "$1" "$1.bak" > /dev/null 2>&1
	fi
	if [ "$(tail -c1 "$1")" = "" ]; then
		echo "$2" | ${STR_SUDO}tee -a "$1" > /dev/null 2>&1
	else
		${STR_SUDO}printf "\n$2" >> "$1"
	fi
	return 0
}

function file_comment_line()
{
    # FILE SEARCH [SUDO] [BACKUP]
	if [ -z "$2" ]; then
        return 1
    fi
    if [ ! -e "$1" ]; then
        return 1
    fi
	if ! file_contains_line "$1" "$2"; then
		return 1
	fi
	local ARG_SUDO=""
	if [ $3 ]; then
		ARG_SUDO="$3"
	fi
	local ARG_BACKUP=""
	if [ $4 ]; then
		ARG_BACKUP="$4"
	fi
	if ! file_replace_line_first "$1" "($2)" "#\1" "$ARG_SUDO" "$ARG_BACKUP"; then
		return 1
	fi
	return 0
}

function file_contains_line()
{
	# FILE STRING
	if [ -z "$2" ]; then
		return 1
	fi
	if [ ! -e "$1" ]; then
		return 1
	fi
	local BOOL_TEST=false
	local IFS_OLD="$IFS"
	IFS="$(echo -en "\n\b")"
	local STR=""
	for STR in "$(grep -e "$2" "$1")"; do
		if [ "$STR" = "$2" ]; then
			BOOL_TEST=true
			break
		fi
	done
	IFS="$IFS_OLD"
	if [ $BOOL_TEST = false ]; then
		return 1
	fi
	return 0
}

function file_delete_line()
{
    # FILE SEARCH [SUDO] [BACKUP]
	if [ -z "$2" ]; then
        return 1
    fi
    if [ ! -e "$1" ]; then
        return 1
    fi
    local BOOL_REGEX=false
    if is_string_regex "$2"; then
    	BOOL_REGEX=true
    	local FILESIZE="$(get_file_size "$1")"
    fi
	if [ $BOOL_REGEX = false ] && ! file_contains_line "$1" "$2"; then
		return 1
	fi
	local STR_SUDO=""
	if [ $3 ] && [ "$3" = "sudo" ]; then
		STR_SUDO="$(maybe_sudo)"
	fi
	local STR_BACKUP=""
	if [ $4 ]; then
		STR_BACKUP=".bak"
	fi
    if [ "$(get_system)" = "Darwin" ]; then
    	if [ "$STR_BACKUP" = "" ]; then
			${STR_SUDO}sed -i '' -E "/$(escape_slashes "$2")/d" "$1"
		else
			${STR_SUDO}sed -i${STR_BACKUP} -E "/$(escape_slashes "$2")/d" "$1"
		fi
	else
		${STR_SUDO}sed -i${STR_BACKUP} -E "/$(escape_slashes "$2")/d" "$1"
	fi
	if [ $BOOL_REGEX = true ]; then
		if [ "$FILESIZE" = "$(get_file_size "$1")" ]; then
			return 1
		fi
	fi
	return 0
}

function file_replace_line()
{
    # FILE SEARCH REPLACE [SUDO] [BACKUP]
	if [ -z "$3" ]; then
        return 1
    fi
    if [ ! -e "$1" ]; then
        return 1
    fi
    local BOOL_REGEX=false
    if is_string_regex "$2"; then
    	BOOL_REGEX=true
    	local FILESIZE="$(get_file_size "$1")"
    fi
	if [ $BOOL_REGEX = false ] && ! file_contains_line "$1" "$2"; then
		return 1
	fi
	local STR_SUDO=""
	if [ $4 ] && [ "$4" = "sudo" ]; then
		STR_SUDO="$(maybe_sudo)"
	fi
	local STR_BACKUP=""
	if [ $5 ]; then
		STR_BACKUP=" -i.bak"
	fi
	${STR_SUDO}perl -0777 -pi${STR_BACKUP} -e "s/^$(escape_slashes "$2")$/$(escape_slashes "$3")/msg" "$1"
	if [ $BOOL_REGEX = true ]; then
		if [ "$FILESIZE" = "$(get_file_size "$1")" ]; then
			return 1
		fi
	fi
	return 0
}

function file_replace_line_first()
{
    # FILE SEARCH REPLACE [SUDO] [BACKUP]
	if [ -z "$3" ]; then
        return 1
    fi
    if [ ! -e "$1" ]; then
        return 1
    fi
    local BOOL_REGEX=false
    if is_string_regex "$2"; then
    	BOOL_REGEX=true
    	local FILESIZE="$(get_file_size "$1")"
    fi
	if [ $BOOL_REGEX = false ] && ! file_contains_line "$1" "$2"; then
		return 1
	fi
	local STR_SUDO=""
	if [ $4 ] && [ "$4" = "sudo" ]; then
		STR_SUDO="$(maybe_sudo)"
	fi
	local STR_BACKUP=""
	if [ $5 ]; then
		STR_BACKUP=" -i.bak"
	fi
	${STR_SUDO}perl -0777 -pi${STR_BACKUP} -e "s/^$(escape_slashes "$2")$/$(escape_slashes "$3")/ms" "$1"
	if [ $BOOL_REGEX = true ]; then
		if [ "$FILESIZE" = "$(get_file_size "$1")" ]; then
			return 1
		fi
	fi
	return 0
}

function file_replace_line_last()
{
	# TODO!
    # FILE SEARCH REPLACE [SUDO] [BACKUP]
	if [ -z "$3" ]; then
        return 1
    fi
    if [ ! -e "$1" ]; then
        return 1
    fi
    local BOOL_REGEX=false
    if [[ "$2" = *\(*\)* ]]; then
    	BOOL_REGEX=true
    	local FILESIZE="$(get_file_size "$1")"
    fi
	if [ $BOOL_REGEX = false ] && ! file_contains_line "$1" "$2"; then
		return 1
	fi
	local STR_SUDO=""
	if [ $4 ] && [ "$4" = "sudo" ]; then
		STR_SUDO="$(maybe_sudo)"
	fi
	local STR_BACKUP=""
	if [ $5 ]; then
		STR_BACKUP=".bak"
	fi
    if [ "$(get_system)" = "Darwin" ]; then
    	if [ "$STR_BACKUP" = "" ]; then
			${STR_SUDO}sed -i '' -E "\$s/$(escape_slashes "$2")/$(escape_slashes "$3")/g" "$1"
		else
			${STR_SUDO}sed -i${STR_BACKUP} -E "\$s/$(escape_slashes "$2")/$(escape_slashes "$3")/g" "$1"
		fi
	else
		${STR_SUDO}sed -i${STR_BACKUP} -E "\$s/$(escape_slashes "$2")/$(escape_slashes "$3")/g" "$1"
	fi
	if [ $BOOL_REGEX = true ]; then
		if [ "$FILESIZE" = "$(get_file_size "$1")" ]; then
			return 1
		fi
	fi
	return 0
}

function get_external_drives_csv()
{
	local ARR_FILES=()
	local STR=""
	if [ "$(get_system)" = "Darwin" ]; then
		local STR_TEST="/Volumes"
		local ARR_TEST=()
		local IFS_OLD="$IFS"
		IFS=$'\n'
		ARR_TEST=( $(find "$STR_TEST" -maxdepth 1) )
		IFS="$IFS_OLD"
		if [ ! "$ARR_TEST" = "" ]; then
			for STR in "${ARR_TEST[@]}"; do
				if [ "$STR" = "$STR_TEST" ]; then
					continue
				fi
				if [ ! "$(diskutil info $(basename "$STR") | grep External)" = "" ]; then
					ARR_FILES+=("$STR")
				fi
			done
		fi
	else
		if [ -e "/etc/mtab" ]; then
			local STR_TEST="/media/usb"
			local CMD_TEST="$(grep -e "$STR_TEST" "/etc/mtab" | tr "\n" " ")"
			if [ ! "$CMD_TEST" = "" ]; then
				local ARR_TEST=()
				local IFS_OLD="$IFS"
				IFS=" " read -r -a ARR_TEST <<< "$CMD_TEST"
				IFS="$IFS_OLD"
				for STR in "${ARR_TEST[@]}"; do
					if [[ "$STR" = "$STR_TEST"* ]]; then
						ARR_FILES+=("$STR")
					fi
				done
			fi
		fi
	fi
	if [ "$ARR_FILES" = "" ]; then
		return 1
	fi
	# convert array to csv
	local LIST=""
	for STR in "${ARR_FILES[@]}"; do
		if [ "$LIST" = "" ]; then
			LIST="$STR"
		else
			LIST="$LIST,$STR"
		fi
	done
	echo "${LIST%,}"
	return 0
}

function get_file_grp()
{
	# FILE
	if [ -z "$1" ]; then
		return 1
	fi
	if [ ! -e "$1" ]; then
		return 1
	fi
	if [ "$(get_system)" = "Darwin" ]; then
		local CMD_TEST="$(stat -Lf '%Sg' "$1")"
	else
		local CMD_TEST="$(stat -Lc %G "$1")"
	fi
	if [ "$CMD_TEST" = "" ]; then
		return 1
	fi
	echo "$CMD_TEST"
	return 0
}

function get_file_list_csv()
{
	# DIR/FILES
	# 1. split all by space.
	local ARR_TEST=()
	local IFS_OLD="$IFS"
	IFS=" " read -r -a ARR_TEST <<< "$*"
	IFS="$IFS_OLD"
	if [ "$ARR_TEST" = "" ]; then
		return 1
	fi
	# 2. find dirs and files containing spaces.
	local ARR_FILES=()
	local STR_TEST=""
	local STR_TEST2=""
	local STR=""
	local STR2=""
	for STR in "${ARR_TEST[@]}"; do
		if [ -d "$STR" ] && dir_has_files "$STR"; then
			for STR2 in $(get_realpath "$STR")/*.*; do
				if [ -e "$STR2" ] && [[ "$(basename "$STR2")" = *.* ]] && [ ! -d "$STR2" ]; then
					ARR_FILES+=("$STR2")
					STR_TEST2=""
				else
					if [ "$STR_TEST2" = "" ]; then
						STR_TEST2="$STR2"
					else
						STR_TEST2="$STR_TEST2 $STR2"
					fi
					if [ -e "$STR_TEST2" ] && [[ "$(basename "$STR_TEST2")" = *.* ]] && [ ! -d "$STR_TEST2" ]; then
						ARR_FILES+=("$STR_TEST2")
						STR_TEST2=""
					fi
				fi
			done
			STR_TEST=""
		elif [ -e "$STR" ] && [[ "$(basename "$STR")" = *.* ]] && [ ! -d "$STR" ]; then
			ARR_FILES+=("$(get_realpath "$STR")")
			STR_TEST=""
		else
			if [ "$STR_TEST" = "" ]; then
				STR_TEST="$STR"
			else
				STR_TEST="$STR_TEST $STR"
			fi
			if [ -e "$STR_TEST" ] && [[ "$(basename "$STR_TEST")" = *.* ]] && [ ! -d "$STR_TEST" ]; then
				ARR_FILES+=("$(get_realpath "$STR_TEST")")
				STR_TEST=""
			fi
		fi
	done
	if [ "$ARR_FILES" = "" ]; then
		return 1
	fi
	# 4. convert array to csv
	local LIST=""
	for STR in "${ARR_FILES[@]}"; do
		if [ "$LIST" = "" ]; then
			LIST="$STR"
		else
			LIST="$LIST,$STR"
		fi
	done
	echo "${LIST%,}"
	return 0
}

function get_file_list_quotes()
{
	# DIR/FILES
	local ARR_TEST=()
	local IFS_OLD="$IFS"
	IFS="," read -r -a ARR_TEST <<< "$(get_file_list_csv "$*")"
	IFS="$IFS_OLD"
	if [ "$ARR_TEST" = "" ]; then
		return 1
	fi
	local LIST=""
	local STR=""
	for STR in "${ARR_TEST[@]}"; do
		if [ "$LIST" = "" ]; then
			LIST="$(quote_string_with_spaces "$STR")"
		else
			LIST="$LIST $(quote_string_with_spaces "$STR")"
		fi
	done
	echo "${LIST% }"
	return 0
}

function get_file_list_video_csv()
{
	# DIR
	local STR_TEST="$*"
	if [ "$STR_TEST" = "" ]; then
		return 1
	fi
	STR_TEST="$(get_realpath "$STR_TEST")"
	if [ ! -d "$STR_TEST" ]; then
		return 1
	fi
	# 1. make the find command
	local CMD_TEST=""
	local ARR_TEST=("avi" "divx" "dv" "flv" "gif" "m4v" "mkv" "mov" "mp4" "mpeg" "mpg" "ogv" "ts" "webm")
	local STR=""
	for STR in "${ARR_TEST[@]}"; do
		if [ "$CMD_TEST" = "" ]; then
			CMD_TEST="-name \"*.$STR\""
		else
			CMD_TEST="$CMD_TEST -o -name \"*.$STR\""
		fi
		STR="$(echo "$STR" | tr '[:lower:]' '[:upper:]')"
		CMD_TEST="$CMD_TEST -o -name \"*.$STR\""
	done
	CMD_TEST="find \"$STR_TEST\" -type f $CMD_TEST"
	# 2. find files
	local ARR_FILES=()
	local IFS_OLD="$IFS"
	IFS=$'\n'
	ARR_FILES=( $(eval "$CMD_TEST") )
	IFS="$IFS_OLD"
	if [ "$ARR_FILES" = "" ]; then
		return 1
	fi
	# 3. convert array to csv
	local LIST=""
	for STR in "${ARR_FILES[@]}"; do
		if [ "$LIST" = "" ]; then
			LIST="$STR"
		else
			LIST="$LIST,$STR"
		fi
	done
	echo "${LIST%,}"
	return 0
}

function get_file_list_video_quotes()
{
	# DIR/FILES
	local ARR_TEST=()
	local IFS_OLD="$IFS"
	IFS="," read -r -a ARR_TEST <<< "$(get_file_list_video_csv "$*")"
	IFS="$IFS_OLD"
	if [ "$ARR_TEST" = "" ]; then
		return 1
	fi
	local LIST=""
	local STR=""
	for STR in "${ARR_TEST[@]}"; do
		if [ "$LIST" = "" ]; then
			LIST="$(quote_string_with_spaces "$STR")"
		else
			LIST="$LIST $(quote_string_with_spaces "$STR")"
		fi
	done
	echo "${LIST% }"
	return 0
}

function get_file_own()
{
	# FILE
	if [ -z "$1" ]; then
		return 1
	fi
	if [ ! -e "$1" ]; then
		return 1
	fi
	if [ "$(get_system)" = "Darwin" ]; then
		local CMD_TEST="$(stat -Lf '%Su' "$1")"
	else
		local CMD_TEST="$(stat -Lc %U "$1")"
	fi
	if [ "$CMD_TEST" = "" ]; then
		return 1
	fi
	echo "$CMD_TEST"
	return 0
}

function get_file_size()
{
	# FILE
	if [ -z "$1" ]; then
		return 1
	fi
	if [ ! -e "$1" ]; then
		return 1
	fi
	if [ "$(get_system)" = "Darwin" ]; then
		local CMD_TEST="$(stat -Lf '%z' "$1")"
	else
		local CMD_TEST="$(stat -Lc %s "$1")"
	fi
	if [ "$CMD_TEST" = "" ]; then
		return 1
	fi
	echo "$CMD_TEST"
	return 0
}

function get_filename()
{
	# FILE
	if [ -z "$1" ]; then
		return 1
	fi
	local STR_TEST="$(basename "$*")"
	echo "${STR_TEST%.*}"
	return 0
}

function get_hostname()
{
	local STR_TEST="localhost"
	if [ -e "/etc/hostname" ]; then
		read -r STR_TEST < /etc/hostname
	fi
	echo "$(trim_space "$STR_TEST")"
	return 0
}

function get_macos_version()
{
	if is_which "sw_vers"; then
		local CMD_TEST="$(sw_vers | grep ProductVersion)"
		if [ ! "$CMD_TEST" = "" ]; then
			echo "$(trim_space "${CMD_TEST##*ProductVersion:}")"
			return 0
		fi
	fi
	return 1
}

function get_os_version()
{
	if [ -e "/etc/debian_version" ]; then
		local STR_TEST=""
		read -r STR_TEST < /etc/debian_version
		echo "$(trim_space "$STR_TEST")"
		return 0
	fi
	if [ -e "/etc/os-release" ]; then
		local CMD_TEST="$(grep -e "VERSION_ID=" /etc/os-release)"
		if [ ! "$CMD_TEST" = "" ]; then
			CMD_TEST="${CMD_TEST##*VERSION_ID=\"}"
			CMD_TEST="${CMD_TEST%\"}"
			echo "$(trim_space "$CMD_TEST")"
			return 0
		fi
	fi
	if [ "$(get_system)" = "Darwin" ]; then
		echo "$(get_macos_version)"
		return 0
	fi
	return 1
}

function get_os_version_id()
{
	if [ -e "/etc/os-release" ]; then
		local CMD_TEST="$(grep -e "VERSION_ID=" /etc/os-release)"
		if [ ! "$CMD_TEST" = "" ]; then
			CMD_TEST="${CMD_TEST##*VERSION_ID=\"}"
			CMD_TEST="${CMD_TEST%\"}"
			echo "$(trim_space "$CMD_TEST")"
			return 0
		fi
	fi
	local STR_TEST=""
	if [ -e "/etc/debian_version" ]; then
		read -r STR_TEST < /etc/debian_version
		echo "$(trim_space "${STR_TEST%%.*}")"
		return 0
	fi
	if [ "$(get_system)" = "Darwin" ]; then
		STR_TEST="$(get_macos_version)"
		echo "${STR_TEST%%.*}"
		return 0
	fi
	return 1
}

function get_pidof()
{
	# PROCESS
	if [ -z "$1" ]; then
		return 1
	fi
	local STR_TEST=""
	if is_which "pidof"; then
		STR_TEST="$(pidof "$1" | awk '{print $1}')"
	fi
	if [ "$STR_TEST" = "" ]; then
		STR_TEST="$(ps -A | grep "$1" | grep -v "grep $1" | awk '{print $1}')"
	fi
	if ! is_int "$STR_TEST"; then
		return 1
	fi
	echo "$STR_TEST"
	return 0
}

function get_realpath()
{
	# PATH
	local STR_TEST="$*"
	if [ "$STR_TEST" = "" ]; then
		return 1
	fi
	if is_which "realpath"; then
		local CMD_TEST="$(realpath -q "$STR_TEST")"
	else
		local CMD_TEST="$(readlink -n "$STR_TEST")"
	fi
	if [ ! "$CMD_TEST" = "" ]; then
		STR_TEST="$CMD_TEST"
		if [ -d "$*" ] && [[ ! "$STR_TEST" = \/* ]]; then
			STR_TEST="/$STR_TEST"
		fi
	fi
	echo "$STR_TEST"
	return 0
}

function get_system()
{
	local STR_TEST="Linux"
	local CMD_TEST="$(uname -s)"
	if [ ! "$CMD_TEST" = "" ]; then
		STR_TEST="$(trim_space "${CMD_TEST%% *}")"
	fi
	echo "$STR_TEST"
	return 0
}

function get_user_dir()
{
	# USER
	if [ -z $1 ]; then
		return 1
	fi
	local CMD_TEST=""
	if is_which "getent"; then
		CMD_TEST="$(getent passwd "$1" | cut -d: -f6)"
		if [ ! "$CMD_TEST" = "" ]; then
			echo "$CMD_TEST"
			return 0
		fi
	fi
	if [ -e "/etc/passwd" ]; then
		CMD_TEST="$(grep -e "$1:" /etc/passwd)"
		if [ ! "$CMD_TEST" = "" ]; then
			echo "$(bash -c "cd ~$(printf %q "$1") && pwd")"
			return 0
		fi
	fi
	if [ "$(get_system)" = "Darwin" ] && [ -d "/Users/$1" ]; then
		echo "$(bash -c "cd ~$(printf %q "$1") && pwd")"
		return 0
	fi
	if [ "$(whoami)" = "$1" ] && [ -n "$HOME" ]; then
		echo "$HOME"
		return 0
	fi
	return 1
}

function has_arg()
{
	# ARGS STRING
	if [ -z "$2" ]; then
		return 1
	fi
	local ARR_TEST=()
	local IFS_OLD="$IFS"
	IFS=" " read -r -a ARR_TEST <<< "$1"
	IFS="$IFS_OLD"
	if [ "$ARR_TEST" = "" ]; then
		return 1
	fi
	local STR=""
	for STR in "${ARR_TEST[@]}"; do
		if [ "$STR" = "$2" ]; then
			return 0
		fi
	done
	return 1
}

function is_int()
{
	# VALUE
	if [ -z "$1" ]; then
		return 1
	fi
	if [ "$1" = "" ]; then
		return 1
	fi
	if [ ! "${1//[0-9]/}" = "" ]; then
		return 1
	fi
	return 0
}

function is_process_running()
{
	# PROCESS
	if [ -z $1 ]; then
		return 1
	fi
	if ! is_int "$(get_pidof "$1")"; then
		return 1
	fi
	return 0
}

function is_string_regex()
{
	# STRING
	local STR_TEST="$*"
    if [[ "$STR_TEST" = *\(*\)* ]] || [[ "$STR_TEST" = *\[*\]* ]]; then
    	return 0
    fi
    return 1
}

function is_sudo()
{
	# [USER]
	if [ $1 ]; then
		local MY_USER="$1"
	else
		local MY_USER="$(whoami)"
	fi
	if [ ! "$MY_USER" = "root" ]; then
		return 1
	fi
	return 0
}

function is_which()
{
	# APP
	if [ -z $1 ]; then
		return 1
	fi
	local CMD_TEST="$(which $1 2>&1 | grep $1)"
	if [ "$CMD_TEST" = "" ] || [[ "$CMD_TEST" = *"not found"* ]]; then
		return 1
	fi
	return 0
}

function kill_process()
{
	# PROCESS...
	local STR_TEST="$*"
	if [ "$STR_TEST" = "" ]; then
		return 1
	fi
	local STR_SUDO="$(maybe_sudo)"
	local ARR_TEST=()
	local IFS_OLD="$IFS"
	IFS=" " read -r -a ARR_TEST <<< "$STR_TEST"
	IFS="$IFS_OLD"
	local STR=""
	for STR in "${ARR_TEST[@]}"; do
		local INT_TEST="$(get_pidof "$STR")"
		if is_int "$INT_TEST"; then
			if is_which "killall"; then
				${STR_SUDO}killall -9 $STR > /dev/null 2>&1
			else
				${STR_SUDO}kill -9 $INT_TEST > /dev/null 2>&1
			fi
		fi
	done
	return 0
}

function kill_tmux()
{
	# SESSION...
	if [ -z "$1" ]; then
		return 1
	fi
	if ! is_which "tmux"; then
		return 1
	fi
	local ARR_TEST=()
	local IFS_OLD="$IFS"
	IFS=" " read -r -a ARR_TEST <<< "$*"
	IFS="$IFS_OLD"
	local STR=""
	for STR in "${ARR_TEST[@]}"; do
		STR="${STR%%.*}"
		tmux kill-ses -t $STR > /dev/null 2>&1
	done
	return 0
}

function maybe_apt_install()
{
	# APP [PACKAGE] [EXIT]
	if [ -z $1 ]; then
		return 1
	fi
	local MY_APP="$1"
	if is_which "$MY_APP"; then
		return 0
	fi
	local MY_PACKAGE="$1"
	if [ $2 ]; then
		MY_PACKAGE="$2"
	fi
	local BOOL_EXIT=false
	if [ $3 ] && [ "$3" = "exit" ]; then
		BOOL_EXIT=true
	fi
    if [ ! "$(get_system)" = "Darwin" ]; then
    	local CMD_TEST="$(maybe_sudo)apt list --installed 2>&1 | grep \"$MY_PACKAGE/\""
		CMD_TEST="$(eval "$CMD_TEST")"
    	if [ "$CMD_TEST" = "" ]; then
			$(maybe_sudo)apt-get -y install $MY_PACKAGE
			sleep 1
			if ! is_which "$MY_APP"; then
				if [ $BOOL_EXIT = true ]; then
					echo "Error in $0 on line $LINENO. Exiting..."
					exit 1
				fi
				return 1
			fi
			return 0
		fi
	fi
	return 1
}

function maybe_brew_install()
{
	# APP [PACKAGE] [EXIT]
	if [ -z $1 ]; then
		return 1
	fi
	local MY_APP="$1"
	if is_which "$MY_APP"; then
		return 0
	fi
	local MY_PACKAGE="$1"
	if [ $2 ]; then
		MY_PACKAGE="$2"
	fi
	local BOOL_EXIT=false
	if [ $3 ] && [ "$3" = "exit" ]; then
		BOOL_EXIT=true
	fi
    if [ "$(get_system)" = "Darwin" ] && is_which "brew"; then
		brew install $MY_PACKAGE
		sleep 1
		if ! is_which "$MY_APP"; then
			if [ $BOOL_EXIT = true ]; then
				echo "Error in $0 on line $LINENO. Exiting..."
				exit 1
			fi
			return 1
		fi
		return 0
	fi
	return 1
}

function maybe_sshpass()
{
	# PASS
	if [ -z $1 ]; then
		return 1
	fi
	if is_which "sshpass" && [ ! "$1" = "" ]; then
		echo "sshpass -p $1 "
		return 0
	fi
	return 1
}

function maybe_sudo()
{
	# [USER]
	if [ $1 ]; then
		local MY_USER="$1"
	else
		local MY_USER="$(whoami)"
	fi
	if is_sudo "$MY_USER"; then
		return 1
	fi
	echo "sudo "
	return 0
}

function maybe_tmux()
{
	# CMD [SESSION] [SUDO]
	if [ -z "$1" ]; then
		return 1
	fi
	local STR_SUDO=""
	if [ $3 ] && [ "$3" = "sudo" ]; then
		STR_SUDO="$(maybe_sudo)"
	fi
	if is_which "tmux"; then
		local ARG_SESSION=""
		# find existing session
		if [ $2 ]; then
			ARG_SESSION="${2%%.*}"
			if [ ! "$(${STR_SUDO}tmux ls 2>&1 | grep $ARG_SESSION:)" = "" ]; then
				${STR_SUDO}tmux send-keys -t $ARG_SESSION "$(escape_quotes "$1")" C-m
				return 0
			fi
		fi
		local ARG_SUDO=""
		if [ $3 ]; then
			ARG_SUDO="$3"
		fi
		# new session
		eval "$(cmd_tmux "$1" "$ARG_SESSION" "$ARG_SUDO")"
		return 0
	else
		echo "$(eval "${STR_SUDO}$1")"
		if [ $? -eq 0 ]; then
			return 0
		fi
	fi
	return 1
}

function quote_string_with_spaces()
{
	# STRING
	if [[ "$*" = *\ * ]]; then
		echo "'$*'"
	else
		echo "$*"
	fi
	return 0
}

function read_keys()
{
	# note: in while loops this will wait for user input.
	local KEY=""
	local INPUT=""
	local INPUT_TIMEOUT="0.01"
	if [ "$(get_system)" = "Darwin" ]; then
		INPUT_TIMEOUT="0"
	fi
	local IFS_OLD="$IFS"
	IFS=
	read -rsn1 INPUT
	case "$INPUT" in
		$'\x1B')
			read -t $INPUT_TIMEOUT -rsn3 INPUT
	        case "$INPUT" in
	        	[A) KEY="UP" ;;
	        	[B) KEY="DOWN" ;;
	        	[C) KEY="RIGHT" ;;
	        	[D) KEY="LEFT" ;;
				[1~) KEY="HOME" ;;
	        	[2~) KEY="INSERT" ;;
	        	[3~) KEY="DELETE" ;;
	        	[4~) KEY="END" ;;
	        	[5~) KEY="PAGEUP" ;;
	        	[6~) KEY="PAGEDOWN" ;;
				*) KEY="ESC" ;;
	        esac
			;;
		"")
    		KEY="ENTER"
			;;
		" ")
    		KEY="SPACE"
			;;
		*)
    		KEY="$INPUT"
			if [ "$(echo $KEY | xargs)" = "" ]; then
				KEY="TAB"
			fi
			;;
	esac
	IFS="$IFS_OLD"
	if [ "$KEY" = "" ]; then
		return 1
	fi
	echo "$KEY"
	return 0
}

function remote_file_exists()
{
	# FILE HOST USER [PASS] [PORT]
	if [ -z $3 ]; then
		return 1
	fi
	local MY_FILE="$1"
	local MY_HOST="$2"
	local MY_USER="$3"
	local MY_PASS=""
	if [ $4 ]; then
		MY_PASS="$4"
	fi
	local MY_PORT=""
	if [ $5 ]; then
		MY_PORT="$5"
	fi
	local CMD_SSH="$(cmd_ssh "$MY_HOST" "$MY_USER" "$MY_PASS" "$MY_PORT")"
	if [ "$CMD_SSH" = "" ]; then
		return 1
	fi
	local CMD_TEST="$CMD_SSH \"ls $MY_FILE 2>&1 | grep 'No such file'\""
    CMD_TEST="$(eval "$CMD_TEST")"
	if [ ! "$CMD_TEST" = "" ]; then
		return 1
	fi
	return 0
}

function script_install()
{
	# FROM [TO] [SUDO]
	if [ -z $1 ]; then
		return 1
	fi
	local STR_FROM="$(get_realpath "$1")"
	if [ ! -f "$STR_FROM" ]; then
		return 1
	fi
	chmod 644 "$STR_FROM"
	chmod +x "$STR_FROM"
	if [ $2 ]; then
		local STR_SUDO=""
		if [ $3 ] && [ "$3" = "sudo" ]; then
			STR_SUDO="$(maybe_sudo)"
		fi
		${STR_SUDO}rm "$2" > /dev/null 2>&1
		${STR_SUDO}ln -s "$STR_FROM" "$2"
	fi
	return 0
}

function script_uninstall()
{
	# FROM [TO] [SUDO]
	if [ -z $1 ]; then
		return 1
	fi
	local STR_FROM="$(get_realpath "$1")"
	if [ ! -f "$STR_FROM" ]; then
		return 1
	fi
	if [ $2 ]; then
		local STR_SUDO=""
		if [ $3 ] && [ "$3" = "sudo" ]; then
			STR_SUDO="$(maybe_sudo)"
		fi
		${STR_SUDO}rm "$2" > /dev/null 2>&1
	fi
	return 0
}

function trim_space()
{
	# STRING
	local STR_TEST="$*"
	echo "$(echo $STR_TEST | xargs)"
	return 0
}
