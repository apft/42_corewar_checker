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
	printf "%s\n" "Usage: ./vm_checker.sh [-bch] exec1 exec2 player"
	printf "%s\n" "  - [-b]     convert player to bytecode first"
	printf "%s\n" "  - [-c]     clean directory at first"
	printf "%s\n" "  - [-h]     print this message and exit"
	printf "%s\n" "  - exec     path to executable"
	printf "%s\n" "  - player   player (.cor file)"
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

timeout_fct()
{
	local bin=$1
	local tmp_out=$2
	shift 2
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
	# remove last 4 lines of file (added by the time command)
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
	shift 2
	local players=$@
	local vm1_status vm2_status
	local diff_tmp="diff_output.tmp"
	local diff_file
	
	initialize_directory
	for player in $players
	do
		if [ ! -f $player ]; then
			printf "${YELLOW}%s${RESET}\n" "Player ($player) not found\n"
		else
			if [ $RUN_ASM -eq 1 ]; then
				$ASM $player > /dev/null 2>&1
				[ $? -ne 0 ] && printf "Could not convert to ASM" && exit
				player=`echo $player | rev | cut -d '.' -f 2 | rev`
				player+=".cor"
			fi
			printf "%-*s  " 60 $player
			timeout_fct $vm1_exec vm1_output.tmp -v 31 $player 2> /dev/null
			vm1_status=$?
			print_status_program $vm1_status
			timeout_fct $vm2_exec vm2_output.tmp -v 31 $player 2> /dev/null
			vm2_status=$?
			print_status_program $vm2_status
			if [ $vm1_status -ne 0 -o $vm2_status -ne 0 ]; then
				print_error "timeout"
				printf "\n"
			else
				diff vm1_output.tmp vm2_output.tmp > $diff_tmp
				if [ -s $diff_tmp ]; then
					diff_file=$DIFF_DIR/`basename $player.diff.$(date "+%Y%M%d%H%M")`
					diff -y vm1_output.tmp vm2_output.tmp > $diff_file
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
	[ -f $diff_tmp ] && rm $diff_tmp
}

clean_dir()
{
	if [ $CLEAN_FIRST -eq 1 ]; then
		[ -d $DIFF_DIR ] && rm -r $DIFF_DIR
	fi
}

DIFF_DIR=".diff"
ASM="../corewar/corewar_resources/asm"
RUN_ASM=0
CLEAN_FIRST=0
TIMEOUT=5 #second
TIMEOUT_STATUS=2 #second

while getopts "bch" o
do
	case "${o}" in
		b)
			RUN_ASM=1
			;;
		c)
			CLEAN_FIRST=1
			;;
		h|*)
			print_usage_and_exit
			;;
	esac
done
if [ $# -lt 3 ];then
	print_usage_and_exit
	exit
fi
shift $((OPTIND - 1))
clean_dir
check_args $@
run_test $@
