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

SCRIPT_ALIAS="vp"

# install
if [ "$1" = "-install" ]; then
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

# vars
if [ "$(get_system)" = "Darwin" ]; then
	TIMEOUT="1"
else
	TIMEOUT="0.01"
fi

# read midi
while true; do
	if [ -f "$FILE_MIDIDUMP" ]; then
	    BEAT="$(tail $FILE_MIDIDUMP | tail -1 | xargs --null)"
	    if [ ! "$BEAT" = "" ]; then
	    	echo "BEAT!"
			echo "" > $FILE_MIDIDUMP
		fi
	fi
done &

# read keys
IFS_OLD="$IFS"
IFS=
while true; do
	read -rsn1 INPUT
	KEY=""
	case "$INPUT" in
		Q)
			break
			;;
		$'\x1B')
			read -t $TIMEOUT -rsn2 INPUT
	        case "$INPUT" in
	        	[A) KEY="UP" ;;
	        	[B) KEY="DOWN" ;;
	        	[C) KEY="RIGHT" ;;
	        	[D) KEY="LEFT" ;;
	        	[2) KEY="INSERT" ;;
	        	[3) KEY="DELETE" ;; # not perfect.
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
    echo "key pressed: $KEY"

done
IFS="$IFS_OLD"

exit 0
