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

if ! is_which "amidi"; then
	exit 1
fi

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
	fi
	echo > $FILE_MIDIDUMP
	amidi -p $1 -d 2>&1 | grep --line-buffered " 01" | tee $FILE_MIDIDUMP
	return 0
}

function mididump_stop()
{
	${MAYBE_SUDO}killall amidi > /dev/null 2>&1
	echo > $FILE_MIDIDUMP
	return 0
}

STR_MIDIPORT=""
STR_MIDIPORT_NEW=""
BOOL_CMD=false

while true; do
	sleep 5

	if [ $BOOL_CMD = false ]; then
		STR_MIDIPORT_NEW="$(get_midi_port)"
		if [ ! "$STR_MIDIPORT_NEW" = "" ]; then
			STR_MIDIPORT="$STR_MIDIPORT_NEW"
			mididump_start "$STR_MIDIPORT"
			BOOL_CMD=true
			continue
		fi
	fi

	if [ $BOOL_CMD = true ]; then
		STR_MIDIPORT_NEW="$(get_midi_port)"
		if [ "$STR_MIDIPORT_NEW" = "" ]; then
			mididump_stop
			BOOL_CMD=false
			continue
		elif [ ! "$STR_MIDIPORT_NEW" = "$STR_MIDIPORT" ]; then
			STR_MIDIPORT="$STR_MIDIPORT_NEW"
			mididump_start "$STR_MIDIPORT"
			continue
		fi
	fi

done

mididump_stop
exit 0
