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
DIR_DATA="$DIRNAME/data"
APP_MIDIDUMP="$DIRNAME/mididump.sh"
FILE_MIDIDUMP="$DIR_DATA/mididump.txt"

MAYBE_SUDO="$(maybe_sudo)"
OWN_LOCAL="$(whoami)"
GRP_LOCAL="$(get_file_grp "$0")"
DIR_LOCAL="$(get_user_dir "$OWN_LOCAL")"
CHMOD_DIRS="755"
CHMOD_FILES="644"
CHMOD_UPLOADS="777"
DIR_SCRIPTS="/usr/local/bin"

if [ ! -d "$DIR_DATA" ]; then
	mkdir -p $DIR_DATA
	chmod $CHMOD_DIRS $DIR_DATA
fi
