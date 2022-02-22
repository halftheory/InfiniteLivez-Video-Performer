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
SCRIPT_ALIAS="lcdhat"
DIR_WORKING="$DIRNAME/$SCRIPT_ALIAS"
FILE_FBCP="fbcp"
FILE_RETROGAME="retrogame"
FILE_RETROGAME_CFG="$DIR_WORKING/$FILE_RETROGAME.cfg"

# usage
if [ -z $1 ] || [ "$1" = "-help" ]; then
	echo "> Usage: $SCRIPT_ALIAS [on|off]"
	exit 1
# install
elif [ "$1" = "-install" ]; then
	if script_install "$0" "$DIR_SCRIPTS/$SCRIPT_ALIAS" "sudo"; then
		# depends
		if has_arg "$*" "-depends"; then
			# https://www.waveshare.com/wiki/1.44inch_LCD_HAT
			# check python version
			FILE_PYTHON=""
			if is_which "python3"; then
				FILE_PYTHON="python3"
			elif is_which "python"; then
				if [ ! "$(python --version 2>&1 | grep "Python 3")" = "" ]; then
					FILE_PYTHON="python"
				fi
			fi
			if [ "$FILE_PYTHON" = "" ]; then
				echo "> Error: python 3 required."
				exit 1
			fi

			# check apt packages
			ARR_TEST=(
				"${FILE_PYTHON}-pip"
				"wiringpi"
			)
			for STR_TEST in "${ARR_TEST[@]}"; do
				CMD_TEST="${MAYBE_SUDO}apt list --installed 2>&1 | grep \"${STR_TEST}/\""
				CMD_TEST="$(eval "$CMD_TEST")"
				if [ "$CMD_TEST" = "" ]; then
					${MAYBE_SUDO}apt-get -y install $STR_TEST
					sleep 1
				fi
			done
			if [ ! "$($FILE_PYTHON -m pip list 2>&1 | grep "No module")" = "" ]; then
				echo "> Error: python pip required."
				exit 1
			fi
			if ! maybe_apt_install "cmake"; then
				echo "> Error: cmake required."
				exit 1
			fi
			if ! maybe_apt_install "wget"; then
				echo "> Error: wget required."
				exit 1
			fi
			if ! maybe_apt_install "7z" "p7zip-full"; then
				echo "> Error: 7z required."
				exit 1
			fi

			# check pip packages
			ARR_TEST=(
				"RPi.GPIO"
				"spidev"
			)
			for STR_TEST in "${ARR_TEST[@]}"; do
				if [ "$($FILE_PYTHON -m pip list 2>&1 | grep "$STR_TEST")" = "" ]; then
					${MAYBE_SUDO}$FILE_PYTHON -m pip install $STR_TEST
					sleep 1
				fi
			done

			if [ ! -d "$DIR_WORKING" ]; then
				mkdir -p "$DIR_WORKING"
				chmod $CHMOD_DIRS "$DIR_WORKING"
			fi

			# install driver
			if [ ! -d "$DIR_WORKING/bcm2835-1.71" ]; then
				wget -q http://www.airspayce.com/mikem/bcm2835/bcm2835-1.71.tar.gz
				if [ $? -eq 0 ] && [ -f "bcm2835-1.71.tar.gz" ]; then
					tar vxfz bcm2835-1.71.tar.gz -C "$DIR_WORKING"
					if [ -d "$DIR_WORKING/bcm2835-1.71" ]; then
						chmod $CHMOD_DIRS "$DIR_WORKING/bcm2835-1.71"
						(cd "$DIR_WORKING/bcm2835-1.71" && ${MAYBE_SUDO}./configure && ${MAYBE_SUDO}make && ${MAYBE_SUDO}make check && ${MAYBE_SUDO}make install)
					fi
					rm -f bcm2835-1.71.tar.gz > /dev/null 2>&1
				else
					echo "> Error: Could not install bcm2835."
					exit 1
				fi
			fi

			# install fbcp
			if [ ! -d "$DIR_WORKING/waveshare_fbcp" ]; then
				wget -q https://www.waveshare.com/w/upload/f/f9/Waveshare_fbcp.7z
				if [ $? -eq 0 ] && [ -f "Waveshare_fbcp.7z" ]; then
					7z x Waveshare_fbcp.7z -o$DIR_WORKING/waveshare_fbcp
					if [ -d "$DIR_WORKING/waveshare_fbcp" ]; then
						chmod $CHMOD_DIRS "$DIR_WORKING/waveshare_fbcp"
						mkdir -p "$DIR_WORKING/waveshare_fbcp/build"
						chmod $CHMOD_DIRS "$DIR_WORKING/waveshare_fbcp/build"
						(cd "$DIR_WORKING/waveshare_fbcp/build" && cmake -DSPI_BUS_CLOCK_DIVISOR=20 -DWAVESHARE_1INCH44_LCD_HAT=ON -DDISPLAY_BREAK_ASPECT_RATIO_WHEN_SCALING=ON -DSTATISTICS=0 .. && make -j)
					fi
					rm -f Waveshare_fbcp.7z > /dev/null 2>&1
				fi
				if ! script_install "$DIR_WORKING/waveshare_fbcp/build/$FILE_FBCP" "$DIR_SCRIPTS/$FILE_FBCP" "sudo"; then
					echo "> Error: Could not install $FILE_FBCP."
					exit 1
				fi
			fi

			# install retrogame
			# https://raw.githubusercontent.com/adafruit/Raspberry-Pi-Installer-Scripts/master/retrogame.sh
			# Download to tmpfile because might already be running
			if [ ! -f "$DIR_WORKING/$FILE_RETROGAME" ]; then
				curl -f -s -o /tmp/$FILE_RETROGAME https://raw.githubusercontent.com/adafruit/Adafruit-Retrogame/master/retrogame
				if [ $? -eq 0 ] && [ -f "/tmp/$FILE_RETROGAME" ]; then
					mv -f /tmp/$FILE_RETROGAME "$DIR_WORKING"
				fi
				if ! script_install "$DIR_WORKING/$FILE_RETROGAME" "$DIR_SCRIPTS/$FILE_RETROGAME" "sudo"; then
					echo "> Error: Could not install $FILE_RETROGAME."
					exit 1
				fi
				FILE_TEST="/etc/udev/rules.d/10-retrogame.rules"
				if [ ! -f "$FILE_TEST" ]; then
					${MAYBE_SUDO}touch "$FILE_TEST"
					${MAYBE_SUDO}chmod $CHMOD_FILES "$FILE_TEST"
				fi
				if ! file_add_line "$FILE_TEST" "SUBSYSTEM==\"input\", ATTRS{name}==\"retrogame\", ENV{ID_INPUT_KEYBOARD}=\"1\"" "sudo"; then
					echo "> Error: Could not install $FILE_TEST."
					exit 1
				fi
			fi
			if [ ! -f "$FILE_RETROGAME_CFG" ]; then
				touch "$FILE_RETROGAME_CFG"
				chmod $CHMOD_FILES "$FILE_RETROGAME_CFG"
				STR_TEST="UP 6
DOWN 19
LEFT 5
RIGHT 26
ENTER 13
1 21
2 20
3 16
ESC 21 20"
				if ! file_add_line "$FILE_RETROGAME_CFG" "$STR_TEST"; then
					echo "> Error: Could not install $FILE_RETROGAME_CFG."
					exit 1
				fi
			fi
		fi # /depends
		echo "> Installed."
		exit 0
	else
		echo "Error in $0 on line $LINENO. Exiting..."
		exit 1
	fi
# uninstall
elif [ "$1" = "-uninstall" ]; then
	if script_uninstall "$0" "$DIR_SCRIPTS/$SCRIPT_ALIAS" "sudo"; then
		# depends
		if has_arg "$*" "-depends"; then
			script_uninstall "$DIR_WORKING/waveshare_fbcp/build/$FILE_FBCP" "$DIR_SCRIPTS/$FILE_FBCP" "sudo"
			script_uninstall "$DIR_WORKING/$FILE_RETROGAME" "$DIR_SCRIPTS/$FILE_RETROGAME" "sudo"
			${MAYBE_SUDO}rm -f /etc/udev/rules.d/10-retrogame.rules > /dev/null 2>&1
			rm -Rf "$DIR_WORKING" > /dev/null 2>&1
		fi
		echo "> Uninstalled."
		exit 0
	else
		echo "Error in $0 on line $LINENO. Exiting..."
		exit 1
	fi
fi

# requirements
if [ "$(lsmod | grep bcm2835)" = "" ]; then
	echo "> bcm2835 not found. Maybe you need to install it."
fi
HAS_FBCP=true
if ! is_which "$FILE_FBCP"; then
	HAS_FBCP=false
	echo "> '$FILE_FBCP' not found. Maybe you need to install it: $SCRIPT_ALIAS -install -depends"
fi
HAS_RETROGAME=true
if ! is_which "$FILE_RETROGAME"; then
	HAS_RETROGAME=false
	echo "> '$FILE_RETROGAME' not found. Maybe you need to install it: $SCRIPT_ALIAS -install -depends"
fi

case "$1" in
	on)
		if [ $HAS_FBCP = true ]; then
			# add to config.txt
			file_add_line_config_after_all "hdmi_force_hotplug=1"
			if ! is_opengl_legacy; then
				file_comment_line "$FILE_CONFIG" "dtoverlay=vc4-kms-v3d-pi4" "sudo"
				file_comment_line "$FILE_CONFIG" "dtoverlay=vc4-kms-v3d" "sudo"
			fi
			read -p "> Resize screen to LCD size 300x300? [y]: " PROMPT_TEST
			PROMPT_TEST="${PROMPT_TEST:-y}"
			if [ "$PROMPT_TEST" = "y" ]; then
				ARR_TEST=(
					"hdmi_group=2"
					"hdmi_mode=87"
					"hdmi_cvt=300 300 60 1 0 0 0"
				)
				for STR_TEST in "${ARR_TEST[@]}"; do
					file_add_line_config_after_all "$STR_TEST"
				done
			fi
			# add to rc.local
			file_add_line_rclocal_before_exit "$FILE_FBCP &"
			# start process
			if ! is_process_running "$FILE_FBCP" && is_which "tmux"; then
				kill_tmux "$FILE_FBCP"
				maybe_tmux "${MAYBE_SUDO}$FILE_FBCP" "$FILE_FBCP"
			fi
		fi
		if [ $HAS_RETROGAME = true ]; then
			# add to rc.local
			file_add_line_rclocal_before_exit "$FILE_RETROGAME \"$FILE_RETROGAME_CFG\" &"
			# start process
			if ! is_process_running "$FILE_RETROGAME" && is_which "tmux"; then
				kill_tmux "$FILE_RETROGAME"
				maybe_tmux "${MAYBE_SUDO}$FILE_RETROGAME \"$FILE_RETROGAME_CFG\"" "$FILE_RETROGAME"
			fi
		fi
		;;

	off)
		# delete from config.txt
		ARR_TEST=(
			"hdmi_group=2"
			"hdmi_mode=87"
			"hdmi_cvt=300 300 60 1 0 0 0"
		)
		for STR_TEST in "${ARR_TEST[@]}"; do
			file_delete_line "$FILE_CONFIG" "$STR_TEST" "sudo"
		done
		# delete from rc.local
		file_delete_line "$FILE_RCLOCAL" "$FILE_FBCP &" "sudo"
		file_delete_line "$FILE_RCLOCAL" "$FILE_RETROGAME \"$FILE_RETROGAME_CFG\" &" "sudo"
		if [ $HAS_FBCP = true ]; then
			kill_tmux "$FILE_FBCP"
			kill_process "$FILE_FBCP"
		fi
		if [ $HAS_RETROGAME = true ]; then
			kill_tmux "$FILE_RETROGAME"
			kill_process "$FILE_RETROGAME"
		fi
		;;

	*)
		echo "Error in $0 on line $LINENO. Exiting..."
		exit 1
		;;
esac

echo "> $SCRIPT_ALIAS will be $1 after rebooting."
exit 0
