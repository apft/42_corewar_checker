#!/bin/bash

################################################################################

# ===> Change this part if needed <=== #########################################

DUMP_OPTION="-dump"		# option to use to dump the memory of your corewar
DUMP_SIZE=32			# number of bytes on one line in the dump output
# ===> end of change <=== ######################################################

# Command to remove the trailing space of each line on output
REMOVE_TRAILING_SPACE="sed 's/ $//'"

# Command to remove all trailing spaces on output
REMOVE_TRAILING_SPACES="sed -E 's/ +$//'"

# Extrat only the part of the output starting with addressed
# an address has is in hexadecimal and starts with '0x'
KEEP_ONLY_MEMORY_WITH_ADDRESSES="grep -E \"^0x[0-9a-fA-F]+\""

# Extract only the output with the dumped memory
# the memory should be displayed with block of bytes in hexadecimal
# space separate each block
KEEP_ONLY_MEMORY_BY_DUMP_SIZE="grep -E \"([0-9a-fA-F]{2} *){$DUMP_SIZE}\""

# In case of an output with addresses on the beginning of line (zaz's output)
# this command can be used to remove them
REMOVE_ADDRESSES="cut -d ':' -f 2 | cut -c 2-"

# If the output has non printable and formating characters, the following
# command remove them
# use this command if colors or bold format are used for instance
REMOVE_NON_PRINT_AND_FORMATING_CHARS="tr -d '\000-\011\013\014\016-\037' | sed -E 's/\[([0-9]+;*)+m//g'"

# ===> Change this part if needed <=== #########################################
# The 'CLEAN_OUTPUT' variable is used to clean user's output
# Adapt this part to your needs

CLEAN_OUTPUT=""
CLEAN_OUTPUT+=" | $KEEP_ONLY_MEMORY_WITH_ADDRESSES | $REMOVE_ADDRESSES"
CLEAN_OUTPUT+=" | $KEEP_ONLY_MEMORY_BY_DUMP_SIZE"
CLEAN_OUTPUT+=" | $REMOVE_NON_PRINT_AND_FORMATING_CHARS"
CLEAN_OUTPUT+=" | $REMOVE_TRAILING_SPACE"
# ===> end of change <=== ######################################################


# By default Zaz's output is cleaned
# if you have the same output, comment the following lines accordingly

ZAZ_DUMP_OPTION="-d"
ZAZ_DUMP_SIZE=64
ZAZ_OUTPUT_PIPE=""
ZAZ_OUTPUT_PIPE+=" | $KEEP_ONLY_MEMORY_WITH_ADDRESSES | $REMOVE_ADDRESSES"
ZAZ_OUTPUT_PIPE+=" | $REMOVE_TRAILING_SPACE"
# allow to format zaz's output to have the same number of bytes on one line
NTH_CHAR_TO_CUT=`echo "3 * $DUMP_SIZE" | bc`
ZAZ_OUTPUT_PIPE+=" | sed 's/./#/$NTH_CHAR_TO_CUT' | tr '#' '\n' | sed '/^$/d'"

################################################################################

SCRIPT_PATH="`dirname $0`"

if [ -f "$SCRIPT_PATH/commons.sh" ]; then
	. "$SCRIPT_PATH/commons.sh"
fi

print_usage_and_exit()
{
	printf "%s\n" "Usage:  $0 <corewar> <player> [...]"
	printf "%s\n" ""
	printf "%s\n" "     <corewar>     path to your executable"
	printf "%s\n" "     <player>      list of players to use"
	exit 1
}

# 1: exec 1
# 2: exec 2
# 3: player
# 4: cycle
# 5: verbose level

run_test(){
	local exec1=$1
	local exec2=$2
	local cycle=$3
	local verbose_lvl=$4
	shift 4
	local players=$@

	# should we keep the stderr in the output ??
	eval "$exec1 $ZAZ_DUMP_OPTION $cycle $players $ZAZ_OUTPUT_PIPE > vm1_output.tmp 2>&1"
	eval "$exec2 $DUMP_OPTION $cycle $players $CLEAN_OUTPUT > vm2_output.tmp 2>&1"
#	$exec1 -v $verbose_lvl -d $cycle $players > vm1_output.tmp 2>&1
#	$exec2 -v $verbose_lvl -d $cycle $players > vm2_output.tmp 2>&1
	diff vm1_output.tmp vm2_output.tmp > diff_output.tmp
}

run_tests(){
	local players=$@
	local nb_of_cycles=`$VM1_EXEC -v 2 $players | grep "It is now cycle" | tail -n 1 | cut -d ' ' -f 5 | bc`
	local min=1
	local max=$nb_of_cycles
	
	printf "Number of cycles: %d\n" $nb_of_cycles
	while [ $min -lt `echo "$max - 1" | bc` ];
	do
		cycle=`echo "($min + $max) / 2" | bc`
		run_test $VM1_EXEC $VM2_EXEC $cycle 0 $players
		if [ -s diff_output.tmp ];then
			max=$cycle
		else
			min=$cycle
		fi
	done
	if [ $max -eq $nb_of_cycles ]; then
		printf "Same dump output\n"
	else
		printf "Dump differs at cycle %d\n" $max
		run_test $VM1_EXEC $VM2_EXEC $max 31 $players
	fi
}

if [ $# -lt 2 ]; then
	print_usage_and_exit
fi

VM1_EXEC="$SCRIPT_PATH/resources/42_corewar"
VM2_EXEC="`add_prefix_if_current_dir $1`"
check_executable $VM2_EXEC
shift
run_tests $@
