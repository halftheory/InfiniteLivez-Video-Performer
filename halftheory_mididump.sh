#!/bin/bash

# import vars
CMD_TEST="$(readlink "$0")"
if [ ! "$CMD_TEST" = "" ]; then
	DIRNAME="$(dirname "$CMD_TEST")"
else
	DIRNAME="$(dirname "$0")"
fi
if [ -f "$DIRNAME/halftheory_vars.sh" ]; then
	. $DIRNAME/halftheory_vars.sh
else
	echo "Error in $0 on line $LINENO. Exiting..."
	exit 1
fi

# vars
SCRIPT_ALIAS="mididump"

# usage
if [ "$1" = "-help" ]; then
	echo "> Usage: $SCRIPT_ALIAS [file]"
	exit 1
# install
elif [ "$1" = "-install" ]; then
	if script_install "$0" "$DIR_SCRIPTS/$SCRIPT_ALIAS" "sudo"; then
		echo "> Installed."
		exit 0
	else
		echo "Error in $0 on line $LINENO. Exiting..."
		exit 1
	fi
# uninstall
elif [ "$1" = "-uninstall" ]; then
	if script_uninstall "$0" "$DIR_SCRIPTS/$SCRIPT_ALIAS" "sudo"; then
		echo "> Uninstalled."
		exit 0
	else
		echo "Error in $0 on line $LINENO. Exiting..."
		exit 1
	fi
fi

# requirements
if ! is_which "amidi"; then
	echo "> 'amidi' not found. Maybe you need to install it."
	exit 1
fi

# vars
BOOL_CMD=false
HAS_FILE=false
if [ $1 ]; then
	FILE_MIDIDUMP="$*"
	DIR_MIDIDUMP="$(dirname "$FILE_MIDIDUMP")"
	if [ ! "$DIR_MIDIDUMP" = "" ]; then
		if [ ! -d "$DIR_MIDIDUMP" ]; then
			mkdir -p "$DIR_MIDIDUMP"
			chmod $CHMOD_DIRS "$DIR_MIDIDUMP"
		fi
	fi
	if [ ! -f "$FILE_MIDIDUMP" ]; then
		touch "$FILE_MIDIDUMP"
		chmod $CHMOD_FILES "$FILE_MIDIDUMP"
	fi
	if [ -f "$FILE_MIDIDUMP" ]; then
		echo > "$FILE_MIDIDUMP"
		HAS_FILE=true
	fi
fi

# functions
function get_midi_port()
{
	local STR_TEST="$(amidi -l | head -2)"
	if [[ ! "$STR_TEST" = *"hw:"* ]]; then
		return 1
	fi
	STR_TEST="$(echo $STR_TEST | tr "\n" " ")"
	local ARR_TEST=()
	local IFS_OLD="$IFS"
	IFS=" " read -r -a ARR_TEST <<< "$STR_TEST"
	IFS="$IFS_OLD"
	local STR=""
	for STR in "${ARR_TEST[@]}"; do
		if [[ "$STR" = "hw:"* ]]; then
			echo "$STR"
			return 0
		fi
	done
	return 1
}

function mididump_start()
{
    # PORT
	if [ -z "$1" ]; then
        return 1
    fi
	if is_process_running "amidi"; then
		kill_process "amidi"
	fi
	if [ $HAS_FILE = true ]; then
		amidi -p $1 -d 2>&1 | grep --line-buffered " 01" | tee "$FILE_MIDIDUMP" > /dev/null &
	else
		amidi -p $1 -d 2>&1 | grep --line-buffered " 01"
	fi
	BOOL_CMD=true
	echo "> Listening on midi port '$1'."
	return 0
}

function mididump_stop()
{
	kill_process "amidi"
	BOOL_CMD=false
	echo "> Looking for midi ports..."
	return 0
}

# start loop
mididump_stop
STR_MIDIPORT=""
STR_MIDIPORT_NEW=""

if [ -t 0 ]; then
	STTY_OLD="$(stty -g)"
	stty -echo -icanon -icrnl time 0 min 0
fi
KEY=""
while [ ! "$KEY" = "q" ]; do
	KEY="$(cat -v)"
	# operation
	STR_MIDIPORT_NEW="$(get_midi_port)"
	if [ $BOOL_CMD = false ]; then
		if [ ! "$STR_MIDIPORT_NEW" = "" ]; then
			STR_MIDIPORT="$STR_MIDIPORT_NEW"
			mididump_start "$STR_MIDIPORT"
		fi
	elif [ $BOOL_CMD = true ]; then
		if [ "$STR_MIDIPORT_NEW" = "" ]; then
			mididump_stop
		elif [ ! "$STR_MIDIPORT_NEW" = "$STR_MIDIPORT" ]; then
			STR_MIDIPORT="$STR_MIDIPORT_NEW"
			mididump_start "$STR_MIDIPORT"
		fi
	fi
	sleep 5
done
if [ -t 0 ]; then
	stty "$STTY_OLD"
fi

mididump_stop > /dev/null 2>&1
echo "> $SCRIPT_ALIAS stopped."
exit 0
