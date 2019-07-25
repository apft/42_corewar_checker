#!/bin/bash

if [ -f commons.sh ]; then
	. commons.sh
else
	printf "%s\n" "The commons.sh file is missing"
	exit 1
fi

print_usage_and_exit()
{
	printf "%s\n" "Usage: ./$0 [-bchl] [-v N] [-t N] exec player"
	printf "%s\n" "  - [-b]       convert player .s file to bytecode first"
	printf "%s\n" "  - [-c]       clean directory at first"
	printf "%s\n" "  - [-a]       enable aff operator"
	printf "%s\n" "  - [-v N]     verbose mode (mode should be between 0 and 31)"
	printf "%s\n" "  - [-t N]     timeout value in seconds (default 10 seconds)"
	printf "%s\n" "  - [-l]       check for leaks"
	printf "%s\n" "  - [-h]       print this message and exit"
	printf "%s\n" "  - exec       path to your executable"
	printf "%s\n" "  - player     player (.cor file, or .s file with the -b option)"
	exit
}

create_filename()
{
	local player=$1
	local suffix=$2

	basename $player.$suffix.$(date "+%Y%M%d%H%M")
}

timeout_fct()
{
	local bin=$1
	local tmp_out=$2
	local leak_file=$3
	shift 3
	local args=$@

	if [ "$bin" != "$VM_42" ]; then
		{ time `cmd_check_leaks $leak_file` $bin $args; } > $tmp_out 2>&1 &
	else
		{ time $bin $args; } > $tmp_out 2>&1 &
	fi
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

run_test()
{
	local vm1_exec=$VM_42
	local vm2_exec=$1
	shift
	local players=$@
	local nbr_of_players=${#}
	local vm1_status vm2_status
	local diff_tmp="diff_output.tmp"
	local diff_file leak_file
	local first_column_width=`compute_column_width $players`
	
	for player in $players
	do
		printf "%-*s  " $first_column_width $player
		if [ ! -f $player ]; then
			printf "${YELLOW}%s${RESET}\n" "Player ($player) not found\n"
			((count_failure++))
		else
			leak_file=$LEAKS_DIR/`create_filename $player "leak"`
			if [ $RUN_ASM -eq 1 ]; then
				$ASM $player > /dev/null 2>&1
				if [ $? -ne 0 ]; then
					print_status $STATUS_ASM_FAILED
					print_status $STATUS_ASM_FAILED
					printf "Could not convert to ASM\n"
					((count_failure++))
					continue
				fi
				player=`echo $player | rev | cut -d '.' -f 2 | rev`
				player+=".cor"
			fi
			timeout_fct $vm1_exec vm1_output.tmp $leak_file $OPT_A $OPT_V $player 2> /dev/null
			vm1_status=$?
			print_status $vm1_status
			timeout_fct $vm2_exec vm2_output.tmp $leak_file $OPT_A $OPT_V $player 2> /dev/null
			get_status $? $leak_file
			vm2_status=$?
			print_status $vm2_status
			if [ $vm1_status -ne 0 -o $vm2_status -ne 0 ]; then
				local vm_timeout=0
				local vm_leaks=0
				for vm_status in $vm1_status $vm2_status
				do
					[ $vm_status -eq 0 ] && printf "ok      "
					[ $vm_status -eq $STATUS_TIMEOUT ] && print_error "timeout  " && vm_timeout=1
					[ $CHECK_LEAKS -ne 0 -a $vm_status -eq $STATUS_LEAKS ] && print_error "leaks    " && vm_leaks=1
				done
				[ $vm_timeout -eq 1 ] && ((count_timeout++))
				[ $vm_leaks -eq 1 ] && ((count_leaks++))
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
	print_summary $nbr_of_players
	[ -f $diff_tmp ] && rm $diff_tmp
}

DIFF_DIR=".diff"
LEAKS_DIR=".leaks"
DIRS="$DIFF_DIR $LEAKS_DIR"

VM_42="./resources/42_corewar"
ASM="../corewar/corewar_resources/asm"

RUN_ASM=0
CLEAN_FIRST=0
CHECK_LEAKS=0
KILL_TIMEOUT=1
TIMEOUT_VALUE=10 #second
OPT_A=""
OPT_V=""
OPT_V_LIMIT_MIN=0
OPT_V_LIMIT_MAX=31

while getopts "bchav:t:l" opt
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
		l)
			CHECK_LEAKS=1
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
if [ $# -lt 2 ];then
	print_usage_and_exit
	exit
fi
[ $CLEAN_FIRST -ne 0 ] && clean_dir $DIRS
check_executable $1
initialize_dir $DIRS
run_test $@
