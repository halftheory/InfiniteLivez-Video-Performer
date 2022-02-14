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
if is_which "omxplayer"; then
	STR_VIDEO_PLAYER="omxplayer"
	STR_VIDEO_PROCESS="omxplayer.bin"
else
	STR_VIDEO_PLAYER="ffplay"
	STR_VIDEO_PROCESS="ffplay"
fi

# install
if [ "$1" = "-install" ]; then
	if script_install "$0" "$DIR_SCRIPTS/$SCRIPT_ALIAS" "sudo"; then
		# depends
		if has_arg "$*" "-depends"; then
			${MAYBE_SUDO}apt-get -y install v4l-utils v4l-conf libv4l-dev bc
			sleep 1
			maybe_apt_install "tmux"
			maybe_apt_install "ffplay" "ffmpeg"
			maybe_apt_install "omxplayer"
		fi
		FILE_TEST="$DIR_LOCAL/.bashrc"
		if [ -e "$FILE_TEST" ] && ! file_contains_line "$FILE_TEST" "alias 123=\"$SCRIPT_ALIAS\""; then
			STR_TEST="alias 123=\"$SCRIPT_ALIAS\"
alias 321=\"sudo halt\""
			file_add_line "$FILE_TEST" "$STR_TEST"
			source "$FILE_TEST"
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
		FILE_TEST="$DIR_LOCAL/.bashrc"
		if [ -e "$FILE_TEST" ]; then
			file_delete_line "$FILE_TEST" "alias 123=\"$SCRIPT_ALIAS\""
			file_delete_line "$FILE_TEST" "alias 321=\"sudo halt\""
		fi
		echo "> Uninstalled."
		exit 0
	else
		echo "Error in $0 on line $LINENO. Exiting..."
		exit 1
	fi
fi

# requirements
if ! is_which "$STR_VIDEO_PLAYER"; then
	echo "> '$STR_VIDEO_PLAYER' not found. Maybe you need to install it: $SCRIPT_ALIAS -install -depends"
	exit 1
fi
if is_process_running "$STR_VIDEO_PROCESS"; then
	kill_process "$STR_VIDEO_PROCESS"
fi

# vars - files
DIR_WORKING="$DIRNAME/$SCRIPT_ALIAS"
DIR_MEDIA="$DIR_WORKING/media"
FILE_BEAT="$DIR_WORKING/beat.txt"
FILE_MIDIDUMP="$DIR_WORKING/mididump.txt"
FILE_OPERATION="$DIR_WORKING/operation.txt"
FILE_SETTINGS="$DIR_WORKING/settings.txt"
if [ ! -d "$DIR_WORKING" ]; then
	mkdir -p "$DIR_WORKING"
	chmod $CHMOD_DIRS "$DIR_WORKING"
fi
if [ ! -d "$DIR_MEDIA" ]; then
	mkdir -p "$DIR_MEDIA"
	chmod $CHMOD_DIRS "$DIR_MEDIA"
fi
if [ ! -f "$FILE_BEAT" ]; then
	touch "$FILE_BEAT"
	chmod $CHMOD_FILES "$FILE_BEAT"
fi
if [ ! -f "$FILE_MIDIDUMP" ]; then
	touch "$FILE_MIDIDUMP"
	chmod $CHMOD_FILES "$FILE_MIDIDUMP"
fi
if [ ! -f "$FILE_OPERATION" ]; then
	touch "$FILE_OPERATION"
	chmod $CHMOD_FILES "$FILE_OPERATION"
fi
if [ ! -f "$FILE_SETTINGS" ]; then
	touch "$FILE_SETTINGS"
	chmod $CHMOD_FILES "$FILE_SETTINGS"
fi
# vars - defaults
DEFAULT_PLAY_MODE="midi"
DEFAULT_FILE_ORDER="random"
DEFAULT_MIDI_PHRASE_LENGTH="4"
DEFAULT_BPM="120"
# vars - settings
PLAY_MODE="$DEFAULT_PLAY_MODE"
FILE_ORDER="$DEFAULT_FILE_ORDER"
MIDI_PHRASE_LENGTH="$DEFAULT_MIDI_PHRASE_LENGTH"
BPM="$DEFAULT_BPM"
# vars - operation
ARR_SESSIONS=()
SESSIONS_COUNTER=0
ARR_MEDIA_ALPHABETICAL=()
MEDIA_ALPHABETICAL_INDEX=0
ARR_MEDIA_RANDOM=()
MEDIA_RANDOM_INDEX=0
INT_BPM_INTERVAL=10
BEAT=1
ARR_PIDS=()
BOOL_SHUTDOWN=false

# get file list
# 1. check usb
STR_TEST="$(get_external_drives_csv)"
if [ ! "$STR_TEST" = "" ]; then
	echo "> External drives found. Looking for videos..."
	ARR_EXTERNAL=()
	IFS_OLD="$IFS"
	IFS="," read -r -a ARR_EXTERNAL <<< "$STR_TEST"
	IFS="$IFS_OLD"
	LIST_EXTERNAL=""
	for STR in "${ARR_EXTERNAL[@]}"; do
		STR="$(get_file_list_video_csv "$STR")"
		if [ ! "$STR" = "" ]; then
			if [ "$LIST_EXTERNAL" = "" ]; then
				LIST_EXTERNAL="$STR"
			else
				LIST_EXTERNAL="$LIST_EXTERNAL,$STR"
			fi
		fi
	done
	if [ ! "$LIST_EXTERNAL" = "" ]; then
		# prompt
		read -p "> Copy all video files from external drives? Note: All existing files will be deleted. [y]: " PROMPT_TEST
		PROMPT_TEST="${PROMPT_TEST:-y}"
		if [ "$PROMPT_TEST" = "y" ]; then
			ARR_TEST=()
			IFS_OLD="$IFS"
			IFS="," read -r -a ARR_TEST <<< "${LIST_EXTERNAL%,}"
			IFS="$IFS_OLD"
			rm -f "$DIR_MEDIA"/* > /dev/null 2>&1
			for STR in "${ARR_TEST[@]}"; do
				cp -f "$STR" "$DIR_MEDIA" > /dev/null 2>&1
				chmod $CHMOD_FILES "$DIR_MEDIA/$(basename "$STR")" > /dev/null 2>&1
			done
			echo "> Total of ${#ARR_TEST[@]} files copied to '$DIR_MEDIA'."
			sleep 1
		fi
	else
		echo "> No videos found."
	fi
	if is_which "eject"; then
		for STR in "${ARR_EXTERNAL[@]}"; do
			${MAYBE_SUDO}eject "$STR" > /dev/null 2>&1
		done
		echo "> External drives ejected."
		sleep 1
	fi
fi
# 2. check for files
delete_macos_system_files "$DIR_WORKING"
if ! dir_has_files "$DIR_MEDIA"; then
	echo "> No files found in '$DIR_MEDIA'. Exiting..."
	exit 1
fi
# 3. convert gifs
ARR_TEST=()
IFS_OLD="$IFS"
IFS=$'\n'
ARR_TEST=( $(find "$DIR_MEDIA" -type f -name "*.gif" -o -name "*.GIF") )
IFS="$IFS_OLD"
if [ ! "$ARR_TEST" = "" ]; then
	# prompt
	read -p "> Convert GIF files (${#ARR_TEST[@]}) to MP4? [y]: " PROMPT_TEST
	PROMPT_TEST="${PROMPT_TEST:-y}"
	if [ "$PROMPT_TEST" = "y" ]; then
		if is_which "ffmpeg"; then
			for STR in "${ARR_TEST[@]}"; do
				STR_NEW="$DIR_MEDIA/$(get_filename "$STR").mp4"
				ffmpeg -hide_banner -v quiet -y -stream_loop 4 -i "$STR" -pix_fmt yuv420p -an -codec:v libx264 -preset veryslow -profile:v high -crf 1 "$STR_NEW" > /dev/null 2>&1
				if [ $? -eq 0 ] && [ -f "$STR_NEW" ]; then
					rm -f "$STR" > /dev/null 2>&1
				fi
			done
		else
			echo "> 'ffmpeg' not found. Maybe you need to install it: $SCRIPT_ALIAS -install -depends"
		fi
	fi
fi
# 4. check for videos
IFS_OLD="$IFS"
IFS="," read -r -a ARR_MEDIA_ALPHABETICAL <<< "$(get_file_list_video_csv "$DIR_MEDIA")"
IFS="$IFS_OLD"
if [ "$ARR_MEDIA_ALPHABETICAL" = "" ]; then
	echo "> No video files found in '$DIR_MEDIA'. Exiting..."
	exit 1
fi

clear

# functions
function update_settings()
{
	# KEY VALUE
	if [ -z "$1" ]; then
		return 1
	fi
	local KEY="$1"
	local VALUE=""
	if [ "$2" ]; then
		VALUE="${@:2}"
	fi
	local BOOL_TEST=false
	local MIN=""
	local MAX=""
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
	# update file
	if [ $BOOL_TEST = true ] && ! file_contains_line "$FILE_SETTINGS" "$KEY=$VALUE"; then
		local STR_TEST="PLAY_MODE=$PLAY_MODE
FILE_ORDER=$FILE_ORDER
MIDI_PHRASE_LENGTH=$MIDI_PHRASE_LENGTH
BPM=$BPM"
		echo "$STR_TEST" > "$FILE_SETTINGS"
	fi
	return 0
}

function update_operation()
{
	# KEY VALUE
	if [ -z "$1" ]; then
		return 1
	fi
	local KEY="$1"
	local VALUE=""
	if [ "$2" ]; then
		VALUE="${@:2}"
	fi
	local BOOL_TEST=false
	case "$KEY" in
		ARR_SESSIONS)
			ARR_SESSIONS=()
			if [ ! "$VALUE" = "" ]; then
				local IFS_OLD="$IFS"
				IFS=" " read -r -a ARR_SESSIONS <<< "$VALUE"
				IFS="$IFS_OLD"
			fi
			VALUE="($VALUE)"
			BOOL_TEST=true
			;;
		SESSIONS_COUNTER)
			SESSIONS_COUNTER="$VALUE"
			BOOL_TEST=true
			;;
		MEDIA_ALPHABETICAL_INDEX)
			if (( $(echo "$VALUE < 0" | bc -l) )); then
				VALUE="$(echo "${#ARR_MEDIA_ALPHABETICAL[@]} - 1" | bc -l)"
			elif (( $(echo "$VALUE >= ${#ARR_MEDIA_ALPHABETICAL[@]}" | bc -l) )); then
				VALUE=0
			fi
			MEDIA_ALPHABETICAL_INDEX="$VALUE"
			BOOL_TEST=true
			;;
		MEDIA_RANDOM_INDEX)
			if (( $(echo "$VALUE < 0" | bc -l) )); then
				VALUE="$(echo "${#ARR_MEDIA_RANDOM[@]} - 1" | bc -l)"
			elif (( $(echo "$VALUE >= ${#ARR_MEDIA_RANDOM[@]}" | bc -l) )); then
				VALUE=0
			fi
			MEDIA_RANDOM_INDEX="$VALUE"
			BOOL_TEST=true
			;;
	esac
	# update file
	if [ $BOOL_TEST = true ] && ! file_contains_line "$FILE_OPERATION" "$KEY=$VALUE"; then
		local STR_TEST="ARR_SESSIONS=(${ARR_SESSIONS[@]})
SESSIONS_COUNTER=$SESSIONS_COUNTER
MEDIA_ALPHABETICAL_INDEX=$MEDIA_ALPHABETICAL_INDEX
MEDIA_RANDOM_INDEX=$MEDIA_RANDOM_INDEX"
		echo "$STR_TEST" > "$FILE_OPERATION"
	fi
	return 0
}

function trigger_beat()
{
	# [INDEX] [PREVIOUS]
	. "$FILE_SETTINGS"
	. "$FILE_OPERATION"
	if [ $1 ] && is_int "$1"; then
		BEAT=$1
	else
		. "$FILE_BEAT"
		((BEAT++))
	fi
	# reset to 1?
	if (($BEAT > 1)); then
		local MAX="4"
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
					((MEDIA_RANDOM_INDEX--))
				else
					((MEDIA_RANDOM_INDEX++))
				fi
				update_operation "MEDIA_RANDOM_INDEX" "$MEDIA_RANDOM_INDEX"
				;;
			*)
				if [ $2 ] && [ "$2" = "previous" ]; then
					((MEDIA_ALPHABETICAL_INDEX--))
				else
					((MEDIA_ALPHABETICAL_INDEX++))
				fi
				update_operation "MEDIA_ALPHABETICAL_INDEX" "$MEDIA_ALPHABETICAL_INDEX"
			;;
		esac
		trigger_video &
		local INT_TEST=$!
		if is_int "$INT_TEST"; then
			ARR_PIDS+=("$INT_TEST")
		fi
	fi
	# update file
	echo "BEAT=$BEAT" > "$FILE_BEAT"
	return 0
}

function trigger_video()
{
	. "$FILE_SETTINGS"
	. "$FILE_OPERATION"
	local STR_TEST=""
	case "$FILE_ORDER" in
		random) STR_TEST="${ARR_MEDIA_RANDOM[$MEDIA_RANDOM_INDEX]}" ;;
		*) STR_TEST="${ARR_MEDIA_ALPHABETICAL[$MEDIA_ALPHABETICAL_INDEX]}" ;;
	esac
	local CMD_TEST=""
	case "$STR_VIDEO_PLAYER" in
		ffplay)
			CMD_TEST="$STR_VIDEO_PLAYER -hide_banner -v quiet -fs -an -sn -noborder -fast -framedrop -infbuf -fflags discardcorrupt -loop 0 $(quote_string_with_spaces "$STR_TEST")"
			;;
		omxplayer)
			CMD_TEST="$STR_VIDEO_PLAYER -o local -b --no-osd --loop $(quote_string_with_spaces "$STR_TEST")"
			;;
	esac
	# start new session
	local STR_SESSION="$SCRIPT_ALIAS$SESSIONS_COUNTER"
	kill_session "$STR_SESSION"
	maybe_tmux "$CMD_TEST" "$STR_SESSION"
	# kill old session
	if [ ! "$ARR_SESSIONS" = "" ]; then
		local BOOL_TEST=true
		# omxplayer - allow extra sessions
		if [ "$STR_VIDEO_PLAYER" = "omxplayer" ]; then
			case "$PLAY_MODE" in
				midi)
					if [ "$MIDI_PHRASE_LENGTH" = "2" ] && ((${#ARR_SESSIONS[@]} < 2)); then
						BOOL_TEST=false
					elif [ "$MIDI_PHRASE_LENGTH" = "1" ] && ((${#ARR_SESSIONS[@]} < 3)); then
						BOOL_TEST=false
					fi
					;;
				bpm)
					if (($BPM == 300)) && ((${#ARR_SESSIONS[@]} < 3)); then
						BOOL_TEST=false
					elif (($BPM >= 200)) && ((${#ARR_SESSIONS[@]} < 2)); then
						BOOL_TEST=false
					fi
					;;
			esac
		fi
		if [ $BOOL_TEST = true ]; then
			sleep 0.5
			local STR=""
			local INT_TEST=0
			for STR in "${ARR_SESSIONS[@]}"; do
				kill_session "$STR"
				unset -v "ARR_SESSIONS[$INT_TEST]"
				((INT_TEST++))
			done
		fi
	fi
	ARR_SESSIONS+=("$STR_SESSION")
	update_operation "ARR_SESSIONS" "${ARR_SESSIONS[@]}"
	((SESSIONS_COUNTER++))
	update_operation "SESSIONS_COUNTER" "$SESSIONS_COUNTER"
	return 0
}

function kill_session()
{
	# SESSION
	if [ -z "$1" ]; then
		return 1
	fi
	tmux send-keys -t $1 "q" > /dev/null 2>&1
	kill_tmux "$1"
	return 0
}

function shuffle_media()
{
	ARR_MEDIA_RANDOM=()
	local INT_TEST=""
	for INT_TEST in $(seq ${#ARR_MEDIA_ALPHABETICAL[@]} | sort -R); do
		((INT_TEST--))
		ARR_MEDIA_RANDOM+=("${ARR_MEDIA_ALPHABETICAL[$INT_TEST]}")
	done
	update_operation "MEDIA_RANDOM_INDEX" "0"
	return 0
}
shuffle_media

# check settings
. "$FILE_SETTINGS"
update_settings "PLAY_MODE" "$PLAY_MODE"
update_operation "ARR_SESSIONS"

# start mididump
if is_which "mididump"; then
	kill_session "mididump"
	kill_process "mididump amidi"
	maybe_tmux "mididump \"$FILE_MIDIDUMP\"" "mididump"
fi
if ! is_process_running "mididump"; then
	rm -f "$FILE_MIDIDUMP" > /dev/null 2>&1
	echo "> Could not start 'mididump'. Removing $(basename "$FILE_MIDIDUMP")..."
fi

# start video
trigger_beat "1"

# start loop - read beats
while true; do
	. "$FILE_SETTINGS"
	case "$PLAY_MODE" in
		midi)
			if [ -f "$FILE_MIDIDUMP" ]; then
			    if [ ! "$(tail "$FILE_MIDIDUMP" | tail -1 | xargs --null)" = "" ]; then
			    	trigger_beat
					echo > "$FILE_MIDIDUMP"
				fi
			fi
			;;
		bpm)
			trigger_beat
			sleep $(awk "BEGIN {print (60/$BPM)}")
			;;
	esac
done &
INT_TEST=$!
if is_int "$INT_TEST"; then
	ARR_PIDS+=("$INT_TEST")
fi

# start loop - read keys
while true; do
	. "$FILE_SETTINGS"
	case "$(read_keys)" in
		ENTER)
			case "$PLAY_MODE" in
				# reset phrase
				midi) update_settings "MIDI_PHRASE_LENGTH" "$DEFAULT_MIDI_PHRASE_LENGTH" ;;
				# reset bpm
				bpm) update_settings "BPM" "$DEFAULT_BPM" ;;
			esac
			# kill extra sessions
			if [ ! "$ARR_SESSIONS" = "" ]; then
				CMD_TEST="$(tmux ls 2>&1 | grep -E "$SCRIPT_ALIAS[0-9]+:" | grep -v "${ARR_SESSIONS[0]}" | awk '{print $1}')"
			else
				CMD_TEST="$(tmux ls 2>&1 | grep -E "$SCRIPT_ALIAS[0-9]+:" | awk '{print $1}')"
			fi
			for STR in "$CMD_TEST"; do
				kill_session "${STR%%:*}"
			done
			update_operation "SESSIONS_COUNTER" "0"
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
			trigger_video &
			INT_TEST=$!
			if is_int "$INT_TEST"; then
				ARR_PIDS+=("$INT_TEST")
			fi
			;;
		b)
			trigger_beat
			;;
		q)
			break
			;;
		ESC)
			BOOL_SHUTDOWN=true
			break
			;;
	esac
done

# stop
if [ ! "$ARR_PIDS" = "" ]; then
	${MAYBE_SUDO}kill ${ARR_PIDS[@]} > /dev/null 2>&1
fi
kill_session "mididump"
for STR in "${ARR_SESSIONS[@]}"; do
	kill_session "$STR"
done
kill_process "mididump amidi $STR_VIDEO_PROCESS"

# shutdown
if [ $BOOL_SHUTDOWN = true ] && [ ! "$(get_system)" = "Darwin" ]; then
	echo "> Shutting down..."
fi

exit 0
