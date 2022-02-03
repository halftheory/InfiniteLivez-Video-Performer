#!/bin/bash

# functions

function check_remote_host()
{
	# HOST
	if [ -z $1 ]; then
		return 1
	fi
	CMD_TEST="$(ping -c1 $1 2>&1 | grep cannot)"
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
	MY_HOST="$1"
	MY_USER="$2"
	MY_PASS=""
	if [ $3 ]; then
		MY_PASS="$3"
	fi
	MY_PORT=""
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
	STR_SESSION=""
	if [ $2 ]; then
		STR_SESSION=" -s $2"
	fi
	STR_SUDO=""
	if [ $3 ] && [ "$3" = "sudo" ]; then
		STR_SUDO="$(maybe_sudo)"
	fi
	echo "${STR_SUDO}tmux new -d${STR_SESSION} \"$(escape_quotes "$1")\" > /dev/null 2>&1"
	return 0
}

function dir_has_files()
{
	# DIR
	if [ -z "$1" ]; then
		return 1
	fi
	STR_TEST="$(get_realpath "$1")"
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
	STR_TEST="$(get_realpath "$1")"
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
	STR_TEST="$*"
	if [[ "$STR_TEST" = *\"* ]]; then
		STR_TEST="${STR_TEST//\"/\\\"}"
	fi
	echo "$STR_TEST"
	return 0
}

function escape_slashes()
{
	# STRING
	STR_TEST="$*"
	if [[ "$STR_TEST" = */* ]]; then
		STR_TEST="${STR_TEST//\//\\/}"
	fi
	echo "$STR_TEST"
	return 0
}

function escape_spaces()
{
	# STRING
	STR_TEST="$*"
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
		ARG_SUDO=""
		if [ $3 ]; then
			ARG_SUDO="$3"
		fi
		ARG_BACKUP=""
		if [ $4 ]; then
			ARG_BACKUP="$4"
		fi
		if file_replace_line_first "$1" "#($2)" "\1" "$ARG_SUDO" "$ARG_BACKUP"; then
			return 0
		fi
	fi
	STR_SUDO=""
	if [ $3 ] && [ "$3" = "sudo" ]; then
		STR_SUDO="$(maybe_sudo)"
	fi
	if [ $4 ]; then
		${STR_SUDO}cp -f $1 $1.bak > /dev/null 2>&1
	fi
	echo "$2" | ${STR_SUDO}tee -a $1 > /dev/null 2>&1
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
	ARG_SUDO=""
	if [ $3 ]; then
		ARG_SUDO="$3"
	fi
	ARG_BACKUP=""
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
	BOOL_TEST=false
	IFS_OLD="$IFS"
	IFS="$(echo -en "\n\b")"
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
    BOOL_REGEX=false
    if is_string_regex "$2"; then
    	BOOL_REGEX=true
    	FILESIZE="$(get_file_size "$1")"
    fi
	if [ $BOOL_REGEX = false ] && ! file_contains_line "$1" "$2"; then
		return 1
	fi
	STR_SUDO=""
	if [ $3 ] && [ "$3" = "sudo" ]; then
		STR_SUDO="$(maybe_sudo)"
	fi
	STR_BACKUP=""
	if [ $4 ]; then
		STR_BACKUP=".bak"
	fi
    if [ "$(get_system)" = "Darwin" ]; then
    	if [ "$STR_BACKUP" = "" ]; then
			${STR_SUDO}sed -i '' -E "/$(escape_slashes "$2")/d" $1
		else
			${STR_SUDO}sed -i${STR_BACKUP} -E "/$(escape_slashes "$2")/d" $1
		fi
	else
		${STR_SUDO}sed -i${STR_BACKUP} -E "/$(escape_slashes "$2")/d" $1
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
    BOOL_REGEX=false
    if is_string_regex "$2"; then
    	BOOL_REGEX=true
    	FILESIZE="$(get_file_size "$1")"
    fi
	if [ $BOOL_REGEX = false ] && ! file_contains_line "$1" "$2"; then
		return 1
	fi
	STR_SUDO=""
	if [ $4 ] && [ "$4" = "sudo" ]; then
		STR_SUDO="$(maybe_sudo)"
	fi
	STR_BACKUP=""
	if [ $5 ]; then
		STR_BACKUP=" -i.bak"
	fi
	${STR_SUDO}perl -0777 -pi${STR_BACKUP} -e "s/^$(escape_slashes "$2")$/$(escape_slashes "$3")/msg" $1
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
    BOOL_REGEX=false
    if is_string_regex "$2"; then
    	BOOL_REGEX=true
    	FILESIZE="$(get_file_size "$1")"
    fi
	if [ $BOOL_REGEX = false ] && ! file_contains_line "$1" "$2"; then
		return 1
	fi
	STR_SUDO=""
	if [ $4 ] && [ "$4" = "sudo" ]; then
		STR_SUDO="$(maybe_sudo)"
	fi
	STR_BACKUP=""
	if [ $5 ]; then
		STR_BACKUP=" -i.bak"
	fi
	${STR_SUDO}perl -0777 -pi${STR_BACKUP} -e "s/^$(escape_slashes "$2")$/$(escape_slashes "$3")/ms" $1
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
    BOOL_REGEX=false
    if [[ "$2" = *\(*\)* ]]; then
    	BOOL_REGEX=true
    	FILESIZE="$(get_file_size "$1")"
    fi
	if [ $BOOL_REGEX = false ] && ! file_contains_line "$1" "$2"; then
		return 1
	fi
	STR_SUDO=""
	if [ $4 ] && [ "$4" = "sudo" ]; then
		STR_SUDO="$(maybe_sudo)"
	fi
	STR_BACKUP=""
	if [ $5 ]; then
		STR_BACKUP=".bak"
	fi
    if [ "$(get_system)" = "Darwin" ]; then
    	if [ "$STR_BACKUP" = "" ]; then
			${STR_SUDO}sed -i '' -E "\$s/$(escape_slashes "$2")/$(escape_slashes "$3")/g" $1
		else
			${STR_SUDO}sed -i${STR_BACKUP} -E "\$s/$(escape_slashes "$2")/$(escape_slashes "$3")/g" $1
		fi
	else
		${STR_SUDO}sed -i${STR_BACKUP} -E "\$s/$(escape_slashes "$2")/$(escape_slashes "$3")/g" $1
	fi
	if [ $BOOL_REGEX = true ]; then
		if [ "$FILESIZE" = "$(get_file_size "$1")" ]; then
			return 1
		fi
	fi
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
		CMD_TEST="$(stat -Lf '%Sg' "$1")"
	else
		CMD_TEST="$(stat -Lc %G "$1")"
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
	ARR_TEST=()
	IFS_OLD="$IFS"
	IFS=" " read -r -a ARR_TEST <<< "$*"
	IFS="$IFS_OLD"
	if [ "$ARR_TEST" = "" ]; then
		return 1
	fi
	# 2. find dirs and files containing spaces.
	ARR_FILES=()
	STR_TEST=""
	for STR in "${ARR_TEST[@]}"; do
		if [ -d "$STR" ] && dir_has_files "$STR"; then
			STR_TEST2=""
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
	LIST=""
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
	ARR_TEST=()
	IFS_OLD="$IFS"
	IFS="," read -r -a ARR_TEST <<< "$(get_file_list_csv "$*")"
	IFS="$IFS_OLD"
	if [ "$ARR_TEST" = "" ]; then
		return 1
	fi
	LIST=""
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
		CMD_TEST="$(stat -Lf '%Su' "$1")"
	else
		CMD_TEST="$(stat -Lc %U "$1")"
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
		CMD_TEST="$(stat -Lf '%z' "$1")"
	else
		CMD_TEST="$(stat -Lc %s "$1")"
	fi
	if [ "$CMD_TEST" = "" ]; then
		return 1
	fi
	echo "$CMD_TEST"
	return 0
}

function get_hostname()
{
	STR_TEST="localhost"
	if [ -e "/etc/hostname" ]; then
		read -r STR_TEST < /etc/hostname
	fi
	echo "$(trim_space "$STR_TEST")"
	return 0
}

function get_macos_version()
{
	if is_which "sw_vers"; then
		CMD_TEST="$(sw_vers | grep ProductVersion)"
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
		read -r STR_TEST < /etc/debian_version
		echo "$(trim_space "$STR_TEST")"
		return 0
	fi
	if [ -e "/etc/os-release" ]; then
		CMD_TEST="$(grep -e "VERSION_ID=" /etc/os-release)"
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
		CMD_TEST="$(grep -e "VERSION_ID=" /etc/os-release)"
		if [ ! "$CMD_TEST" = "" ]; then
			CMD_TEST="${CMD_TEST##*VERSION_ID=\"}"
			CMD_TEST="${CMD_TEST%\"}"
			echo "$(trim_space "$CMD_TEST")"
			return 0
		fi
	fi
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
	if is_which "pidof"; then
		echo "$(pidof "$1")"
	else
		echo "$(ps -A | grep "$1" | awk '{print $1}')"
	fi
	return 0
}

function get_realpath()
{
	# PATH
	STR_TEST="$*"
	if [ "$STR_TEST" = "" ]; then
		return 1
	fi
	if is_which "realpath"; then
		CMD_TEST="$(realpath -q "$STR_TEST")"
	else
		CMD_TEST="$(readlink -n "$STR_TEST")"
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
	STR_TEST="Linux"
	CMD_TEST="$(uname -s)"
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
	ARR_TEST=()
	IFS_OLD="$IFS"
	IFS=" " read -r -a ARR_TEST <<< "$1"
	IFS="$IFS_OLD"
	if [ "$ARR_TEST" = "" ]; then
		return 1
	fi
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
	if [ -z $1 ]; then
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
	if [ "$(get_pidof "$1")" = "" ]; then
		return 1
	fi
	return 0
}

function is_string_regex()
{
	# STRING
	STR_TEST="$*"
    if [[ "$STR_TEST" = *\(*\)* ]] || [[ "$STR_TEST" = *\[*\]* ]]; then
    	return 0
    fi
    return 1
}

function is_sudo()
{
	# [USER]
	if [ $1 ]; then
		MY_USER="$1"
	else
		MY_USER="$(whoami)"
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
	CMD_TEST="$(which $1 2>&1 | grep $1)"
	if [ "$CMD_TEST" = "" ] || [[ "$CMD_TEST" = *"not found"* ]]; then
		return 1
	fi
	return 0
}

function maybe_install()
{
	# APP [PACKAGE] [EXIT]
	if [ -z $1 ]; then
		return 1
	fi
	MY_APP="$1"
	if is_which "$MY_APP"; then
		return 0
	fi
	MY_PACKAGE="$1"
	if [ $2 ]; then
		MY_PACKAGE="$2"
	fi
	BOOL_EXIT=false
	if [ $3 ] && [ "$3" = "exit" ]; then
		BOOL_EXIT=true
	fi
    if [ "$(get_system)" = "Darwin" ]; then
    	if is_which "brew"; then
    		brew install $MY_PACKAGE
    		sleep 1
    	fi
    else
    	CMD_TEST="$(maybe_sudo)apt list --installed 2>&1 | grep \"$MY_PACKAGE/\""
		CMD_TEST="$(eval "$CMD_TEST")"
    	if [ "$CMD_TEST" = "" ]; then
			$(maybe_sudo)apt-get -y install $MY_PACKAGE
			sleep 1
		fi
	fi
	if ! is_which "$MY_APP"; then
		if [ $BOOL_EXIT = true ]; then
			echo "Error in $0 on line $LINENO. Exiting..."
			exit 1
		fi
		return 1
	fi
	return 0
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
		MY_USER="$1"
	else
		MY_USER="$(whoami)"
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
	STR_SUDO=""
	if [ $3 ] && [ "$3" = "sudo" ]; then
		STR_SUDO="$(maybe_sudo)"
	fi
	if is_which "tmux"; then
		ARG_SESSION=""
		# find existing session
		if [ $2 ]; then
			if [ ! "$(${STR_SUDO}tmux ls 2>&1 | grep $2:)" = "" ]; then
				${STR_SUDO}tmux send-keys -t $2 "$(escape_quotes "$1")" C-m
				return 0
			fi
			ARG_SESSION="$2"
		fi
		ARG_SUDO=""
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

function remote_file_exists()
{
	# FILE HOST USER [PASS] [PORT]
	if [ -z $3 ]; then
		return 1
	fi
	MY_FILE="$1"
	MY_HOST="$2"
	MY_USER="$3"
	MY_PASS=""
	if [ $4 ]; then
		MY_PASS="$4"
	fi
	MY_PORT=""
	if [ $5 ]; then
		MY_PORT="$5"
	fi
	CMD_SSH="$(cmd_ssh "$MY_HOST" "$MY_USER" "$MY_PASS" "$MY_PORT")"
	if [ "$CMD_SSH" = "" ]; then
		return 1
	fi
	CMD_TEST="$CMD_SSH \"ls $MY_FILE 2>&1 | grep 'No such file'\""
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
	STR_FROM="$(get_realpath "$1")"
	if [ ! -f "$STR_FROM" ]; then
		return 1
	fi
	chmod 644 $STR_FROM
	chmod +x $STR_FROM
	if [ $2 ]; then
		STR_SUDO=""
		if [ $3 ] && [ "$3" = "sudo" ]; then
			STR_SUDO="$(maybe_sudo)"
		fi
		${STR_SUDO}rm $2 > /dev/null 2>&1
		${STR_SUDO}ln -s $STR_FROM $2
	fi
	return 0
}

function script_uninstall()
{
	# FROM [TO] [SUDO]
	if [ -z $1 ]; then
		return 1
	fi
	STR_FROM="$(get_realpath "$1")"
	if [ ! -f "$STR_FROM" ]; then
		return 1
	fi
	if [ $2 ]; then
		STR_SUDO=""
		if [ $3 ] && [ "$3" = "sudo" ]; then
			STR_SUDO="$(maybe_sudo)"
		fi
		${STR_SUDO}rm $2 > /dev/null 2>&1
	fi
	return 0
}

function trim_space()
{
	# STRING
	STR_TEST="$*"
	echo "$(echo $STR_TEST | xargs)"
	return 0
}
