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
if [ "$(get_system)" = "Darwin" ]; then
	FILE_PLAYER="$DIRNAME/video-performer.app/Contents/MacOS/video-performer"
else
	FILE_PLAYER="$DIRNAME/video-performer"
fi
STR_PROCESS="video-performer"
DIR_DATA="$DIRNAME/data"
FILE_MIDIDUMP="$DIR_DATA/mididump.txt"

# install
if [ "$1" = "-install" ]; then
	# remove old files.
	rm -Rf "$DIRNAME/$SCRIPT_ALIAS" > /dev/null 2>&1
	rm -f "$DIRNAME/video-performer.sh" > /dev/null 2>&1
	if script_install "$0" "$DIR_SCRIPTS/$SCRIPT_ALIAS" "sudo"; then
		# depends
		if has_arg "$*" "-depends"; then
			echo "> Installing script dependencies..."
			${MAYBE_SUDO}apt-get -y install v4l-utils v4l-conf libv4l-dev bc tmux ffmpeg
			sleep 1
			echo "> Installing openframeworks dependencies..."
			${MAYBE_SUDO}apt-get -y install freeglut3-dev libasound2-dev libxmu-dev libxxf86vm-dev g++ libgl1-mesa-dev libglu1-mesa-dev libraw1394-dev libudev-dev libdrm-dev libglew-dev libopenal-dev libsndfile1-dev libfreeimage-dev libcairo2-dev libfreetype6-dev libssl-dev libpulse-dev libusb-1.0-0-dev libgtk-3-dev libopencv-dev libegl1-mesa-dev libglvnd-dev libgles2-mesa-dev libassimp-dev librtaudio-dev libboost-filesystem-dev libglfw3-dev  liburiparser-dev libcurl4-openssl-dev libpugixml-dev
			sleep 1
			echo "> Installing gstreamer..."
			${MAYBE_SUDO}apt-get -y install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-libav gstreamer1.0-pulseaudio gstreamer1.0-x gstreamer1.0-plugins-bad gstreamer1.0-alsa gstreamer1.0-plugins-base gstreamer1.0-plugins-good
			sleep 1
		fi
		# /depends
		script_install "$FILE_PLAYER"
		# gpu_mem=256
		if ! file_contains_line "$FILE_CONFIG" "gpu_mem=256"; then
			if [ "$(get_system)" = "Darwin" ]; then
				${MAYBE_SUDO}sed -i '' -E "s/gpu_mem=[0-9]*/gpu_mem=256/g" "$FILE_CONFIG"
			else
				${MAYBE_SUDO}sed -i -E "s/gpu_mem=[0-9]*/gpu_mem=256/g" "$FILE_CONFIG"
			fi
			file_add_line_config_after_all "gpu_mem=256"
		fi
		# bash alias
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
		if has_arg "$*" "-depends"; then
			rm -Rf "$DIR_DATA" > /dev/null 2>&1
		fi
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
if [ ! -e "$FILE_PLAYER" ]; then
	echo "> '$(basename "$FILE_PLAYER")' not found. Maybe you need to install it: $SCRIPT_ALIAS -install -depends"
	exit 1
fi
if is_process_running "$STR_PROCESS"; then
	kill_process "$STR_PROCESS"
fi
if [ ! -d "$DIR_DATA" ]; then
	mkdir -p "$DIR_DATA"
	chmod $CHMOD_DIRS "$DIR_DATA"
fi

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
			rm -f "$DIR_DATA"/* > /dev/null 2>&1
			for STR in "${ARR_TEST[@]}"; do
				cp -f "$STR" "$DIR_DATA" > /dev/null 2>&1
				chmod $CHMOD_FILES "$DIR_DATA/$(basename "$STR")" > /dev/null 2>&1
			done
			echo "> Total of ${#ARR_TEST[@]} files copied to '$DIR_DATA'."
			sleep 1
		fi
	else
		echo "> No video files found."
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
delete_macos_system_files "$DIR_DATA"
if ! dir_has_files "$DIR_DATA"; then
	echo "> No files found in '$DIR_DATA'. Exiting..."
	exit 1
fi
# 3. convert gifs
ARR_TEST=()
IFS_OLD="$IFS"
IFS=$'\n'
ARR_TEST=( $(find "$DIR_DATA" -type f -name "*.gif" -o -name "*.GIF") )
IFS="$IFS_OLD"
if [ ! "$ARR_TEST" = "" ]; then
	# prompt
	read -p "> Convert GIF files (${#ARR_TEST[@]}) to MP4? [y]: " PROMPT_TEST
	PROMPT_TEST="${PROMPT_TEST:-y}"
	if [ "$PROMPT_TEST" = "y" ]; then
		if is_which "ffmpeg"; then
			for STR in "${ARR_TEST[@]}"; do
				STR_NEW="$DIR_DATA/$(get_filename "$STR").mp4"
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
ARR_TEST=()
IFS_OLD="$IFS"
IFS="," read -r -a ARR_TEST <<< "$(get_file_list_video_csv "$DIR_DATA")"
IFS="$IFS_OLD"
if [ "$ARR_TEST" = "" ]; then
	echo "> No video files found in '$DIR_DATA'. Exiting..."
	exit 1
fi

# functions
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

# start mididump
if is_which "mididump"; then
	kill_session "mididump"
	kill_process "mididump amidi"
	if [ ! -f "$FILE_MIDIDUMP" ]; then
		touch "$FILE_MIDIDUMP"
		chmod $CHMOD_FILES "$FILE_MIDIDUMP"
	fi
	maybe_tmux "mididump \"$FILE_MIDIDUMP\"" "mididump"
fi
if ! is_process_running "mididump"; then
	rm -f "$FILE_MIDIDUMP" > /dev/null 2>&1
	echo "> Could not start 'mididump'. Removing $(basename "$FILE_MIDIDUMP")..."
fi

# start renicer
if is_which "renicer"; then
	kill_session "renicer"
	kill_process "renicer"
	maybe_tmux "renicer $STR_PROCESS persistent" "renicer"
fi

# start video
eval "$FILE_PLAYER"

# stop
kill_session "mididump renicer"
kill_process "mididump amidi renicer $STR_PROCESS"

echo "> Shutting down..."
exit 0
