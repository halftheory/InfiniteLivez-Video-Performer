#!/bin/bash

# import functions
CMD_TEST="$(readlink "$0")"
if [ ! "$CMD_TEST" = "" ]; then
	DIRNAME="$(dirname "$CMD_TEST")"
else
	DIRNAME="$(dirname "$0")"
fi
if [ -f "$DIRNAME/halftheory_functions.sh" ]; then
	. $DIRNAME/halftheory_functions.sh
else
	echo "Error in $0 on line $LINENO. Exiting..."
	exit 1
fi

# vars
DIRNAME="$(get_realpath "$DIRNAME")"
MAYBE_SUDO="$(maybe_sudo)"
OWN_LOCAL="$(whoami)"
GRP_LOCAL="$(get_file_grp "$0")"
DIR_LOCAL="$(get_user_dir "$OWN_LOCAL")"
CHMOD_DIRS="755"
CHMOD_FILES="644"
DIR_SCRIPTS="/usr/local/bin"
FILE_CONFIG="/boot/config.txt"
FILE_RCLOCAL="/etc/rc.local"

# functions
function is_opengl_legacy()
{
	if file_contains_line "$FILE_CONFIG" "dtoverlay=vc4-kms-v3d" || file_contains_line "$FILE_CONFIG" "dtoverlay=vc4-kms-v3d-pi4"; then
		return 1
	fi
	return 0
}

function is_vcgencmd_working()
{
	local STR_TEST="$(get_os_version_id)"
	if is_which "vcgencmd" && is_int "$STR_TEST" && (($STR_TEST < 11)); then
		return 0
	fi
	return 1
}

function file_add_line_config_after_all()
{
	# STRING
	if [ -z "$1" ]; then
		return 1
	fi
	if ! file_contains_line "$FILE_CONFIG" "$*"; then
		if file_contains_line "$FILE_CONFIG" "#$*"; then
			file_add_line "$FILE_CONFIG" "$*" "sudo"
		elif ! file_replace_line_first "$FILE_CONFIG" "(\[all\])" "\1\n$*" "sudo"; then
			file_add_line "$FILE_CONFIG" "$*" "sudo"
		fi
	else
		return 1
	fi
	return 0
}

function file_add_line_rclocal_before_exit()
{
	# STRING
	if [ -z "$1" ]; then
		return 1
	fi
	if ! file_contains_line "$FILE_RCLOCAL" "$*"; then
		if file_contains_line "$FILE_RCLOCAL" "#$*"; then
			file_add_line "$FILE_RCLOCAL" "$*" "sudo"
		elif ! file_replace_line_first "$FILE_RCLOCAL" "(exit 0)" "$*\n\1" "sudo"; then
			file_add_line "$FILE_RCLOCAL" "$*" "sudo"
		fi
	else
		return 1
	fi
	return 0
}
