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

# install
if [ "$1" = "-install" ]; then
	if script_install "$0"; then
		echo "> Installed."
		exit 0
	else
		echo "Error in $0 on line $LINENO. Exiting..."
		exit 1
	fi
# uninstall
elif [ "$1" = "-uninstall" ]; then
	if script_uninstall "$0"; then
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
if [ ! -d "$DIR_DATA" ]; then
	mkdir -p "$DIR_DATA"
	chmod $CHMOD_DIRS "$DIR_DATA"
fi

# vars
BOOL_CMD=false

# functions
function get_midi_port()
{
	STR_TEST="$(amidi -l | head -2)"
	if [[ ! "$STR_TEST" = *"hw:"* ]]; then
		return 1
	fi
	STR_TEST="$(echo $STR_TEST | tr "\n" " ")"
	ARR_TEST=()
	IFS_OLD="$IFS"
	IFS=" " read -r -a ARR_TEST <<< "$STR_TEST"
	IFS="$IFS_OLD"
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
		mididump_stop
	else
		echo > "$FILE_MIDIDUMP"
	fi
	amidi -p $1 -d 2>&1 | grep --line-buffered " 01" | tee "$FILE_MIDIDUMP"
	BOOL_CMD=true
	return 0
}

function mididump_stop()
{
	kill_process "amidi"
	echo > "$FILE_MIDIDUMP"
	BOOL_CMD=false
	return 0
}

STR_MIDIPORT=""
STR_MIDIPORT_NEW=""
while true; do
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

mididump_stop
exit 0
