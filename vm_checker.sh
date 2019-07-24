#!/bin/bash

if [ -f colors.sh ]; then
	. colors.sh
fi

print_ok()
{
	printf "${GREEN}%s${RESET}" "$1"
}

print_error()
{
	printf "${RED}%s${RESET}" "$1"
}

print_warning()
{
	printf "${YELLOW}%s${RESET}" "$1"
}

print_usage_and_exit()
{
	printf "%s\n" "Usage: ./vm_checker.sh [-bch] [-v N] [-t N] exec1 exec2 player"
	printf "%s\n" "  - [-b]       convert player to bytecode first"
	printf "%s\n" "  - [-c]       clean directory at first"
	printf "%s\n" "  - [-a]       enable aff operator"
	printf "%s\n" "  - [-v N]     verbose mode (mode should be between 0 and 31)"
	printf "%s\n" "  - [-t N]     timeout value in seconds (default 10 seconds)"
	printf "%s\n" "  - [-h]       print this message and exit"
	printf "%s\n" "  - exec       path to executable"
	printf "%s\n" "  - player     player (.cor file)"
	exit
}

check_executable()
{
	if [ ! -f $1 ];then
		printf "%s\n" "Executable ($1) not found"
		exit
	fi
	if [ ! -x $1 ];then
		printf "%s\n" "Executable ($1) not executable"
		exit
	fi
}

check_args()
{
	check_executable $1
	check_executable $2
}

initialize_directory()
{
	[ ! -d $DIFF_DIR ] && mkdir $DIFF_DIR
	[ ! -d $LEAKS_DIR ] && mkdir $LEAKS_DIR
}

clean_dir()
{
	if [ $CLEAN_FIRST -eq 1 ]; then
		[ -d $DIFF_DIR ] && rm -r $DIFF_DIR
		[ -d $LEAKS_DIR ] && rm -r $LEAKS_DIR
	fi
}

compute_first_column_width()
{
	local players=$@
	local width=0
	local length

	for player in $players
	do
		length=${#player}
		if [ $width -lt $length ]; then
			width=$length
		fi
	done
	echo $((width + 5))
}

create_filename()
{
	local player=$1
	local suffix=$2

	basename $player.$suffix.$(date "+%Y%M%d%H%M")
}

command_check_leaks()
{
	local leak_file=$1

	if [ $CHECK_LEAKS -ne 0 ]; then
		printf "valgrind --log-file=$leak_file --leak-check=full"
	fi
}

check_leaks()
{
	local leak_file=$1
	local definitely_lost="^==[0-9]+==\s+definitely lost: 0 bytes in 0 blocks$"
	local indirectly_lost="^==[0-9]+==\s+indirectly lost: 0 bytes in 0 blocks$"
	local still_reachable="^==[0-9]+==\s+still reachable: 200 bytes in [0-9] blocks$"

	for leak in "$definitely_lost" "$indirectly_lost" "$still_reachable"
	do
		if ! grep -E "$leak" $leak_file > /dev/null; then
			return $STATUS_LEAKS
		fi
	done
	rm $leak_file
	return 0
}

timeout_fct()
{
	local bin=$1
	local tmp_out=$2
	local leak_file=$3
	shift 3
	local args=$@

	{ time `command_check_leaks $leak_file` $bin $args; } > $tmp_out 2>&1 &
	local pid=$!
	sleep $TIMEOUT_VALUE &
	local pid_sleep=$!
	while ps -p $pid_sleep > /dev/null
	do
		if ! ps -p $pid > /dev/null; then
			kill $pid_sleep > /dev/null 2>&1
		fi
	done
	if ps -p $pid > /dev/null; then
		kill $pid && killall `basename $bin` > /dev/null 2>&1
		return $STATUS_TIMEOUT
	fi
	# remove last 4 lines of file (added by the time command)
	sed -i '' -e :a -e '$d;N;2,4ba' -e 'P;D' $tmp_out
	return 0
}

get_status()
{
	local status=$1
	local leak_file=$2

	[ $status -ne 0 ] && return $status
	check_leaks $leak_file
	return $?
}

print_status_program()
{
	if [ $1 -eq 0 ]; then
		printf "${GREEN}✔ $RESET"
	else
		printf "${RED}✗ $RESET"
	fi
}

run_test()
{
	local vm1_exec=$1
	local vm2_exec=$2
	shift 2
	local players=$@
	local nbr_of_players=${#}
	local vm1_status vm2_status
	local diff_tmp="diff_output.tmp"
	local diff_file leak_file
	local first_column_width=`compute_first_column_width $players`
	local count_success=0
	local count_failure=0
	local count_timeout=0
	
	initialize_directory
	for player in $players
	do
		printf "%-*s  " $first_column_width $player
		if [ ! -f $player ]; then
			printf "${YELLOW}%s${RESET}\n" "Player ($player) not found\n"
		else
			if [ $RUN_ASM -eq 1 ]; then
				$ASM $player > /dev/null 2>&1
				if [ $? -ne 0 ]; then
					print_status_program 1
					print_status_program 1
					printf "Could not convert to ASM\n"
					continue
				fi
				player=`echo $player | rev | cut -d '.' -f 2 | rev`
				player+=".cor"
			fi
			leak_file=$LEAKS_DIR/`create_filename $player "vm1.leak"`
			timeout_fct $vm1_exec vm1_output.tmp $leak_file $OPT_A $OPT_V $player 2> /dev/null
			get_status $? $leak_file
			vm1_status=$?
			print_status_program $vm1_status
			leak_file=$LEAKS_DIR/`create_filename $player "vm2.leak"`
			timeout_fct $vm2_exec vm2_output.tmp $leak_file $OPT_A $OPT_V $player 2> /dev/null
			get_status $? $leak_file
			vm2_status=$?
			print_status_program $vm2_status
			if [ $vm1_status -ne 0 -o $vm2_status -ne 0 ]; then
				local vm_timeout=0
				local vm_leaks=0
				for vm_status in $vm1_status $vm2_status
				do
					[ $vm_status -eq 0 ] && printf "ok        "
					[ $vm_status -eq $STATUS_TIMEOUT ] && print_error "timeout  " && vm_timeout=1
					[ $vm_status -eq $STATUS_LEAKS ] && print_error "leaks    " && vm_leaks=1
				done
				[ $vm_timeout -eq 1 ] && ((count_timeout++))
			else
				diff vm1_output.tmp vm2_output.tmp > $diff_tmp
				if [ -s $diff_tmp ]; then
					((count_failure++))
					diff_file=$DIFF_DIR/`create_filename $player "diff"`
					diff -y vm1_output.tmp vm2_output.tmp > $diff_file
					print_error "Booo!"
					printf " see $diff_file"
				else
					((count_success++))
					print_ok "Good!"
				fi
			fi
			printf "\n"
			[ $RUN_ASM -eq 1 ] && rm $player
		fi
	done
	printf "\n"
	printf "Success: ${GREEN}%4d/%d${RESET}\n" $count_success $nbr_of_players
	printf "Failure: ${RED}%4d/%d${RESET}\n" $count_failure $nbr_of_players
	printf "Timeout: ${YELLOW}%4d/%d${RESET}\n" $count_timeout $nbr_of_players
	[ -f $diff_tmp ] && rm $diff_tmp
}

DIFF_DIR=".diff"
LEAKS_DIR=".leaks"
ASM="../corewar/corewar_resources/asm"

RUN_ASM=0
CLEAN_FIRST=0
CHECK_LEAKS=1
TIMEOUT_VALUE=10 #second
OPT_A=""
OPT_V=""
OPT_V_LIMIT_MIN=0
OPT_V_LIMIT_MAX=31

STATUS_TIMEOUT=2
STATUS_LEAKS=3

VALGRIND_LOG=""

while getopts "bchav:t:" opt
do
	case "$opt" in
		b)
			RUN_ASM=1
			;;
		c)
			CLEAN_FIRST=1
			;;
		a)
			OPT_A="-a"
			;;
		t)
			if echo $OPTARG | grep -E "^[0-9]+$" > /dev/null 2>&1; then
				TIMEOUT_VALUE=$OPTARG
			fi
			;;
		v)
			if echo $OPTARG | grep -E "^[0-9]+$" > /dev/null 2>&1; then
				if [ $OPTARG -ge $OPT_V_LIMIT_MIN -a $OPTARG -le $OPT_V_LIMIT_MAX ]; then
					OPT_V="-v $OPTARG"
				else
					print_usage_and_exit
				fi
			else
				print_usage_and_exit
			fi
			;;
		h|*)
			print_usage_and_exit
			;;
	esac
done
shift $((OPTIND - 1))
if [ $# -lt 3 ];then
	print_usage_and_exit
	exit
fi
clean_dir
check_args $@
run_test $@
