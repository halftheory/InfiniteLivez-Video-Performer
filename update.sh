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

# prompt to continue
read -p "> Continue update? [y]: " PROMPT_TEST
PROMPT_TEST="${PROMPT_TEST:-y}"
if [ ! "$PROMPT_TEST" = "y" ]; then
	exit 0
fi

# vars
DIRNAME="$(get_realpath "$DIRNAME")"

# functions
function scripts_install()
{
	if script_install "$DIRNAME/install.sh"; then
		$DIRNAME/install.sh
		return 0
	fi
	return 1
}
function scripts_uninstall()
{
	if script_install "$DIRNAME/install.sh"; then
		$DIRNAME/install.sh -uninstall
		return 0
	fi
	return 1
}

# git
if [ -d "$DIRNAME/.git" ]; then
	if maybe_apt_install "git"; then
		scripts_uninstall
		(cd $DIRNAME && git fetch && git pull)
		if scripts_install; then
			echo "> Updated."
			exit 0
		fi
	fi
fi

# curl
STR_REPO="$(basename "$DIRNAME")"
if [ "$STR_REPO" = "" ]; then
	exit 1
fi
if maybe_apt_install "wget"; then
	wget -q https://github.com/halftheory/$STR_REPO/archive/refs/heads/main.zip
	if [ $? -eq 0 ] && [ -f "main.zip" ]; then
		if is_which "unzip"; then
			unzip -oq main.zip -d $DIRNAME
		else
			tar vxfz main.zip -C $DIRNAME
		fi
		if [ -d "$DIRNAME/$STR_REPO-main" ]; then
			chmod $CHMOD_DIRS $DIRNAME/$STR_REPO-main
			scripts_uninstall
			cp -Rf $DIRNAME/$STR_REPO-main/* $DIRNAME/
			rm -Rf $DIRNAME/$STR_REPO-main > /dev/null 2>&1
			if scripts_install; then
				echo "> Updated."
			fi
		fi
		rm -f main.zip > /dev/null 2>&1
		exit 0
	fi
fi

exit 1
