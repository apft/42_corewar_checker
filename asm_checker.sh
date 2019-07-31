#!/bin/bash

SCRIPT_PATH=`dirname $0`

if [ -f "$SCRIPT_PATH/commons.sh" ]; then
	. "$SCRIPT_PATH/commons.sh"
else
	printf "%s\n" "The commons.sh file is missing"
	exit 1
fi

print_usage_and_exit()
{
	printf "%s\n" "Usage:  `basename $0` [-lch] <asm> [<champion>...]"
	printf "%s\n" "    -l             check for leaks"
	printf "%s\n" "    -c             clean directory at first"
	printf "%s\n" "    -h             print this message and exit"
	printf "%s\n" "    <asm>          path to your asm executable file"
	printf "%s\n" "    <champion>...  path to the champions to test, if empty use a set of predefined champs stored in \`$CHAMPIONS_FOLDER'"
	exit
}

print_error_and_exit()
{
	printf "Error: %s\n" "$1"
	exit 1
}

print_output()
{
	local width=$1
	shift
	local status=$1
	shift
	local output="$@"
	local msg=`cat "$output" | tr '\n' ' '`

	if [ $status -eq 139 ]; then
		printf "${RED}%-70s${RESET}" "segfault"
	else
		printf "%-*s" $width "$msg"
	fi
}

run_checks()
{
	local output_42=".output_42"
	local output_usr=".output_usr"
	local bytecode_42=".bytecode_42"
	local bytecode_usr=".bytecode_usr"
	local status_42 status_usr asm_file
	local valgrind_log valgrind_cmd
	local first_column_width=`compute_column_width $CHAMPIONS`
	local nbr_of_players="`echo $CHAMPIONS | wc -w | bc`"

	for champ in $CHAMPIONS
	do
		printf "%-*s  " $first_column_width $champ
		if [ ! -f $champ -a ! -c $champ]; then
			printf "${YELLOW}%s${RESET}\n" "Player ($champ) not found\n"
			((count_failure++))
		else
			valgrind_log="$DIR_LEAKS/`basename $champ`.leaks"
			valgrind_cmd="`cmd_check_leaks $valgrind_log`"

			asm_file="`echo $champ | rev | cut -d '.' -f 2- | rev`.cor"
			$valgrind_cmd $ASM_USR $champ > $output_usr 2>&1
			get_status $? $output_usr $valgrind_log
			status_usr=$?
			print_status $status_usr
			[ -f $asm_file ] && mv $asm_file $bytecode_usr
			$ASM_42 $champ > $output_42 2>&1
			status_42=$?
			print_status $status_42
			[ -f $asm_file ] && mv $asm_file $bytecode_42

			if [ $status_usr -eq $STATUS_LEAKS ]; then
				printf "${RED}%-8s${RESET} %s" "leaks" "see $valgrind_log"
				printf "\n"
				((count_leaks++))
				continue
			elif [ $status_usr -ne 0 -a $status_42 -ne 0 ]; then
				printf "${GREEN}%-8s${RESET}" "good"
				((count_success++))
			elif [ $status_usr -eq 0 -a $status_42 -eq 0 ]; then
				local diff=`diff $bytecode_42 $bytecode_usr 2>&1`
				if [ "$diff" ]; then
					printf "${RED}%-8s${RESET} %s" "error" "bytecode files differ"
					((count_failure++))
				else
					printf "${GREEN}%-8s${RESET}" "success"
					((count_success++))
				fi
			else
				printf "${RED}%-8s${RESET}" "error"
				((count_failure++))
			fi
			[ $status_usr -ne 0 ] && print_output 70 $status_usr $output_usr
			[ $status_42 -ne 0 ] && print_output 110 $status_42 $output_42
			printf "\n"
		fi
	done
	printf "\n"
	print_summary $nbr_of_players
	rm $output_42 $output_usr $bytecode_42 $bytecode_usr
}

ASM_42="`add_prefix_if_current_dir $SCRIPT_PATH/resources/42_asm`"
ASM_USR=""
CHAMPIONS_FOLDER="$SCRIPT_PATH/champs"
CHAMPIONS_DEV="/dev/null /dev/random /dev/urandom"
CHAMPIONS="`find ${CHAMPIONS_FOLDER} -type f -name \"*.s\"`"
CHAMPIONS+=" $CHAMPIONS_DEV"

CLEAN_FIRST=0
CHECK_LEAKS=0
KILL_TIMEOUT=0

DIR_LEAKS=".leaks"
DIRS="$DIR_LEAKS"

while getopts "lch" opt
do
	case $opt in
		c)
			CLEAN_FIRST=1
			;;
		l)
			if ! bin_is_installed "valgrind"; then
				exit
			fi
			CHECK_LEAKS=1
			;;
		h|*)
			print_usage_and_exit
			;;
	esac
done
shift $((OPTIND - 1))
[ ! -x "$ASM_42" ] && chmod u+x "$ASM_42"
check_executable "$ASM_42"
[ $# -lt 1 ] && print_usage_and_exit
check_executable $1
ASM_USR="`add_prefix_if_current_dir $1`"
shift
[ $# -gt 0 ] && CHAMPIONS="$@"
[ $CLEAN_FIRST -ne 0 ] && clean_dir $DIRS
initialize_dir $DIRS
run_checks 2> /dev/null
