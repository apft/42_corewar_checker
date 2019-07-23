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
	printf "%s\n" "Usage: ./vm_checker.sh [-b] exec1 exec2 player"
	printf "%s\n" "  - [-b]   convert player to bytecode first"
	printf "%s\n" "  - exec   Path to executable"
	printf "%s\n" "  - player Player (.cor file)"
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
	if [ $# -lt 3 ];then
		print_usage_and_exit
		exit
	fi
	[ "$1" = "-b" ] && RUN_ASM=1 && shift
	check_executable $1
	check_executable $2
}

print_header()
{
	local width=35

	printf "%*s" 5 ""
	printf "$UNDERLINE"
	printf "%*s  %*s" $width $1 $width $1
	printf "$RESET"
	printf "\n"
}

timeout_fct()
{
	local bin=$1
	local tmp_out=$2
	shift
	shift
	local args=$@

	{ time $bin $args; } > $tmp_out 2>&1 &
	local pid=$!
	sleep $TIMEOUT &
	local pid_sleep=$!
	while ps -p $pid_sleep > /dev/null
	do
		if ! ps -p $pid > /dev/null; then
			kill $pid_sleep > /dev/null 2>&1
		fi
	done
	if ps -p $pid > /dev/null; then
		kill $pid && killall `basename $bin` > /dev/null 2>&1
		return $TIMEOUT_STATUS
	fi
	# remove last 4 lines of file (addes by the time command)
	sed -i '' -e :a -e '$d;N;2,4ba' -e 'P;D' $tmp_out
	return 0
}

print_status_program()
{
	if [ $1 -eq 0 ]; then
		printf "${GREEN}✔ $RESET"
	else
		printf "${RED}✗ $RESET"
	fi
}

print_timeout()
{
	local width=35

	printf "$RED%*s  $RESET" $width "timeout"
}

initialize_directory()
{
	[ ! -d $DIFF_DIR ] && mkdir $DIFF_DIR
}

run_test()
{
	local vm1_exec=$1
	local vm2_exec=$2
	shift
	shift
	local players=$@
	local vm1_status vm2_status diff_file
	
	initialize_directory
	print_header $vm1_exec $vm2_exec
	for player in $players
	do
		if [ ! -f $player ]; then
			printf "${YELLOW}%s${RESET}\n" "Player ($player) not found\n"
		else
			if [ $RUN_ASM -eq 1 ]; then
				$ASM $player
				[ $? -ne 0 ] && printf "Could not convert to ASM" && exit
				player=`echo $player | rev | cut -d '.' -f 2 | rev`
				player+=".cor"
			fi
			timeout_fct $vm1_exec vm1_output.tmp -v 31 $player 2> /dev/null
			vm1_status=$?
			print_status_program $vm1_status
			timeout_fct $vm2_exec vm2_output.tmp -v 31 $player 2> /dev/null
			vm2_status=$?
			print_status_program $vm2_status
			#$vm2_exec -v 31 $player > vm2_output.tmp 2>&1
			printf " "
			if [ $vm1_status -ne 0 -o $vm2_status -ne 0 ]; then
				[ $vm1_status -eq $TIMEOUT_STATUS ] && print_timeout $vm1_exec
				[ $vm2_status -eq $TIMEOUT_STATUS ] && print_timeout $vm2_exec
				printf "\n"
			else
				diff_file=$DIFF_DIR/`basename $player.diff.$(date "+%Y%M%d%H%M")`
				diff -y vm1_output.tmp vm2_output.tmp > $diff_file
				if [ -s diff_output.tmp ]; then
					print_error "Booo!"
					printf " see $diff_file"
					printf "\n"
				else
					print_ok "Good!"
					printf "\n"
				fi
			fi
			[ $RUN_ASM -eq 1 ] && rm $player
		fi
	done
}

DIFF_DIR=".diff"
ASM="../corewar/corewar_resources/asm"
RUN_ASM=0
TIMEOUT=5 #second
TIMEOUT_STATUS=2 #second

check_args $@
[ $RUN_ASM -eq 1 ] && shift
run_test $@
