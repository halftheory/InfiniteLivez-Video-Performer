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
		# depends
		if has_arg "$*" "-depends"; then
			maybe_apt_install "ffplay" "ffmpeg"
			# usbmount
		fi
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
STR_PROCESS="ffplay"
if ! is_which "$STR_PROCESS"; then
	echo "> '$STR_PROCESS' not found. Maybe you need to install it: $SCRIPT_ALIAS -install -depends"
	exit 1
fi
if is_process_running "$STR_PROCESS"; then
	echo "> Process '$STR_PROCESS' is already running. Exiting..."
	exit 1
fi
if [ ! -d "$DIR_DATA" ]; then
	mkdir -p $DIR_DATA
	chmod $CHMOD_DIRS $DIR_DATA
fi
if [ ! -d "$DIR_MEDIA" ]; then
	mkdir -p $DIR_MEDIA
	chmod $CHMOD_DIRS $DIR_MEDIA
fi
HAS_SHUF=false
if is_which "shuf"; then
	HAS_SHUF=true
fi

# vars
ARR_MEDIA_ALPHABETICAL=()
ARR_MEDIA_RANDOM=()
INT_BPM_INTERVAL=10
BOOL_SHUTDOWN=false
# vars - default
DEFAULT_PLAY_MODE="midi"
DEFAULT_FILE_ORDER="random"
DEFAULT_MIDI_PHRASE_LENGTH="4"
DEFAULT_BPM="120"
# vars - settings
PLAY_MODE="$DEFAULT_PLAY_MODE"
FILE_ORDER="$DEFAULT_FILE_ORDER"
MIDI_PHRASE_LENGTH="$DEFAULT_MIDI_PHRASE_LENGTH"
BPM="$DEFAULT_BPM"
if [ -f "$FILE_SETTINGS" ]; then
	. "$FILE_SETTINGS"
else
	echo > $FILE_SETTINGS
fi
CURRENT_MEDIA_RANDOM_INDEX=0
CURRENT_MEDIA_ALPHABETICAL_INDEX=0
BEAT=1

# functions
function trigger_beat()
{
	# [INDEX] [PREVIOUS]
	if [ $1 ] && is_int "$1"; then
		BEAT=$1
	else
		. "$FILE_BEAT"
		((BEAT++))
	fi

	# reset to 1?
	if (($BEAT > 1)); then
		case "$PLAY_MODE" in
			midi) MAX="$MIDI_PHRASE_LENGTH" ;;
			*) MAX="4" ;;
		esac
		if (($BEAT > $MAX)); then
			BEAT=1
		fi
	fi

	# change the file
	if (($BEAT == 1)); then
		case "$FILE_ORDER" in
			random)
				if [ $2 ] && [ "$2" = "previous" ]; then
					((CURRENT_MEDIA_RANDOM_INDEX--))
					if (($CURRENT_MEDIA_RANDOM_INDEX < 0)); then
						CURRENT_MEDIA_RANDOM_INDEX=$((${#ARR_MEDIA_ALPHABETICAL[@]} - 1))
					fi
				else
					((CURRENT_MEDIA_RANDOM_INDEX++))
					if (($CURRENT_MEDIA_RANDOM_INDEX >= ${#ARR_MEDIA_ALPHABETICAL[@]})); then
						CURRENT_MEDIA_RANDOM_INDEX=0
					fi
				fi
				;;
			*)
				if [ $2 ] && [ "$2" = "previous" ]; then
					((CURRENT_MEDIA_ALPHABETICAL_INDEX--))
					if (($CURRENT_MEDIA_ALPHABETICAL_INDEX < 0)); then
						CURRENT_MEDIA_ALPHABETICAL_INDEX=$((${#ARR_MEDIA_ALPHABETICAL[@]} - 1))
					fi
				else
					((CURRENT_MEDIA_ALPHABETICAL_INDEX++))
					if (($CURRENT_MEDIA_ALPHABETICAL_INDEX >= ${#ARR_MEDIA_ALPHABETICAL[@]})); then
						CURRENT_MEDIA_ALPHABETICAL_INDEX=0
					fi
				fi
			;;
		esac
		update_placeholder
	fi

	echo "BEAT $BEAT"
	echo "BEAT=$BEAT" > $FILE_BEAT
	return 0
}

function update_settings()
{
	# KEY VALUE
	if [ -z "$2" ]; then
		return 1
	fi
	KEY="$1"
	VALUE="$2"
	BOOL_TEST=false
	case "$KEY" in
		PLAY_MODE)
			PLAY_MODE="$VALUE"
			BOOL_TEST=true
			;;
		FILE_ORDER)
			FILE_ORDER="$VALUE"
			BOOL_TEST=true
			;;
		MIDI_PHRASE_LENGTH)
			MIN=1
			MAX=64
			if (( $(echo "$VALUE >= $MIN" | bc -l) )) && (( $(echo "$VALUE <= $MAX" | bc -l) )); then
				VALUE="${VALUE%%.*}"
				MIDI_PHRASE_LENGTH="$VALUE"
				BOOL_TEST=true
			fi
			;;
		BPM)
			MIN=10
			MAX=300
			if (( $(echo "$VALUE >= $MIN" | bc -l) )) && (( $(echo "$VALUE <= $MAX" | bc -l) )); then
				VALUE="${VALUE%%.*}"
				BPM="$VALUE"
				BOOL_TEST=true
			fi
			;;
	esac
	if [ $BOOL_TEST = true ]; then
		if ! file_contains_line "$FILE_SETTINGS" "$KEY=$VALUE"; then
			if ! file_replace_line_first "$FILE_SETTINGS" "$KEY=(\w*)" "$KEY=$VALUE"; then
				file_add_line "$FILE_SETTINGS" "$KEY=$VALUE"
			fi
		fi
	fi
	return 0
}

function update_placeholder()
{
	case "$FILE_ORDER" in
		random) STR_TEST="${ARR_MEDIA_RANDOM[$CURRENT_MEDIA_RANDOM_INDEX]}" ;;
		*) STR_TEST="${ARR_MEDIA_ALPHABETICAL[$CURRENT_MEDIA_ALPHABETICAL_INDEX]}" ;;
	esac
	ln -sf $(quote_string_with_spaces "$STR_TEST") $(quote_string_with_spaces "$FILE_PLACEHOLDER") > /dev/null 2>&1
	return 0
}

function shuffle_media()
{
	# https://unix.stackexchange.com/questions/526723/bash-how-to-avoid-duplicate-result-from-random-list/526724
	if [ $HAS_SHUF = true ]; then
		ARR_MEDIA_RANDOM=($(shuf -e "${ARR_MEDIA_ALPHABETICAL[@]}"))
	else
		ARR_MEDIA_RANDOM=()
		for INT_TEST in $(seq ${#ARR_MEDIA_ALPHABETICAL[@]} | sort -R); do
			((INT_TEST--))
			ARR_MEDIA_RANDOM+=("${ARR_MEDIA_ALPHABETICAL[$INT_TEST]}")
		done
	fi
	CURRENT_MEDIA_RANDOM_INDEX=0
	return 0
}

#function copy_video_files()
# {
	# avi divx dv flv gif m4v mov mp4 mpeg mpg ogv ts webm
	# uppercase, lowercase extensions
#}
# check usb
# usb found, checking total size of video files, check free space on /home minus DIR_MEDIA
# prompt to continue
#read -p "> Copy all video files from USB? [y]: " PROMPT_TEST
#PROMPT_TEST="${PROMPT_TEST:-y}"
#if [ "$PROMPT_TEST" = "y" ]; then
#	rm $DIR_MEDIA/* > /dev/null 2>&1
	# copy usb to $DIR_MEDIA
#fi

# get file list
delete_macos_system_files "$DIR_DATA"
LIST="$(get_file_list_csv "$DIR_MEDIA")"
IFS_OLD="$IFS"
IFS="," read -r -a ARR_MEDIA_ALPHABETICAL <<< "$LIST"
IFS="$IFS_OLD"
if [ "$ARR_MEDIA_ALPHABETICAL" = "" ]; then
	echo "> No files found in '$DIR_MEDIA'. Exiting..."
	exit 1
fi
shuffle_media

# create playlist
if [ ! -f "$FILE_PLAYLIST" ]; then
	touch $FILE_PLAYLIST
	chmod $CHMOD_FILES $FILE_PLAYLIST
	STR_TEST="ffconcat version 1.0
file $(quote_string_with_spaces "$FILE_PLACEHOLDER")
file $(quote_string_with_spaces "$FILE_PLACEHOLDER")"
	file_add_line $FILE_PLAYLIST "$STR_TEST"
fi

# create placeholder
if [ ! -e "$FILE_PLACEHOLDER" ]; then
	update_placeholder
fi

# start midi
if ! is_process_running "$(basename "$SH_MIDIDUMP")" && [ -f "$SH_MIDIDUMP" ]; then
	maybe_tmux "$SH_MIDIDUMP &" "$(basename "$SH_MIDIDUMP")"
	if ! is_process_running "$(basename "$SH_MIDIDUMP")"; then
		rm $FILE_MIDIDUMP > /dev/null 2>&1
		echo "> Could not start $(basename "$SH_MIDIDUMP"). Removing $(basename "$FILE_MIDIDUMP")..."
	fi
fi

# play -nostdin To explicitly disable console interactions?
trigger_beat "1"
CMD_TEST="ffplay -hide_banner -v quiet -fs -an -sn -noborder -fast -framedrop -infbuf -fflags discardcorrupt -safe 0 -loop 0 -f concat -i $(quote_string_with_spaces "$FILE_PLAYLIST") &"
eval "$CMD_TEST"

# read beats
while true; do
	. "$FILE_SETTINGS"
	case "$PLAY_MODE" in
		midi)
			if [ -f "$FILE_MIDIDUMP" ]; then
			    if [ ! "$(tail $FILE_MIDIDUMP | tail -1 | xargs --null)" = "" ]; then
			    	trigger_beat
					echo "" > $FILE_MIDIDUMP
				fi
			fi
			;;
		bpm)
			sleep $(awk "BEGIN {print (60/$BPM)}")
			trigger_beat
			;;
	esac
done & PID_BEATS=$!

# read keys
if [ "$(get_system)" = "Darwin" ]; then
	INPUT_TIMEOUT="1"
else
	INPUT_TIMEOUT="0.01"
fi
IFS_OLD="$IFS"
IFS=
while true; do
	read -rsn1 INPUT
	KEY=""
	case "$INPUT" in
		q)
			break
			;;
		$'\x1B')
			read -t $INPUT_TIMEOUT -rsn2 INPUT
	        case "$INPUT" in
	        	[A) KEY="UP" ;;
	        	[B) KEY="DOWN" ;;
	        	[C) KEY="RIGHT" ;;
	        	[D) KEY="LEFT" ;;
	        	[2) KEY="INSERT" ;;
	        	[3) KEY="DELETE" ;; # not perfect
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

    # trigger actions
	case "$KEY" in
		ENTER)
			case "$PLAY_MODE" in
				# reset phrase
				midi) update_settings "MIDI_PHRASE_LENGTH" "$DEFAULT_MIDI_PHRASE_LENGTH" ;;
				# reset bpm
				bpm) update_settings "BPM" "$DEFAULT_BPM" ;;
			esac
			trigger_beat "1"
			;;
		UP)
			case "$PLAY_MODE" in
				# more beats
				midi) update_settings "MIDI_PHRASE_LENGTH" "$(echo "$MIDI_PHRASE_LENGTH / 2" | bc -l)" ;;
				# faster bpm
				bpm) update_settings "BPM" "$(echo "$BPM + $INT_BPM_INTERVAL" | bc -l)" ;;
			esac
			;;
		DOWN)
			case "$PLAY_MODE" in
				# less beats
				midi) update_settings "MIDI_PHRASE_LENGTH" "$(echo "$MIDI_PHRASE_LENGTH * 2" | bc -l)" ;;
				# slower bpm
				bpm) update_settings "BPM" "$(echo "$BPM - $INT_BPM_INTERVAL" | bc -l)" ;;
			esac
			;;
		LEFT)
			# previous file
			trigger_beat "1" "previous"
			;;
		RIGHT)
			# next file
			trigger_beat "1"
			;;
		1)
			update_settings "PLAY_MODE" "midi"
			;;
		2)
			update_settings "PLAY_MODE" "bpm"
			;;
		3)
			# toggle file order random/alphabetical
			case "$FILE_ORDER" in
				random) update_settings "FILE_ORDER" "alphabetical" ;;
				*) update_settings "FILE_ORDER" "random" ;;
			esac
			update_placeholder
			;;
		b)
			trigger_beat
			;;
		ESC)
			BOOL_SHUTDOWN=true
			break
			;;
	esac

done
IFS="$IFS_OLD"

if is_int "$PID_BEATS"; then
	${MAYBE_SUDO}kill $PID_BEATS > /dev/null 2>&1
fi

# shutdown
if [ $BOOL_SHUTDOWN = true ] && [ ! "$(get_system)" = "Darwin" ]; then
	${MAYBE_SUDO}killall $STR_PROCESS > /dev/null 2>&1
	${MAYBE_SUDO}killall $(basename "$SH_MIDIDUMP") > /dev/null 2>&1
	${MAYBE_SUDO}killall amidi > /dev/null 2>&1
	sudo halt
fi

exit 0
