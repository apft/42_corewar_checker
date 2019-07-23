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

run_test()
{
	local vm1_exec=$1
	local vm2_exec=$2
	shift
	shift
	local players=$@
	
	for player in $players
	do
		if [ ! -f $player ]; then
			printf "${YELLOW}%s${RESET}\n" "Player ($player) not found"
		else
			if [ $RUN_ASM -eq 1 ]; then
				echo $player
				$ASM $player
				[ $? -ne 0 ] && printf "Could not convert to ASM" && exit
				player=`echo $player | rev | cut -d '.' -f 2 | rev`
				player+=".cor"
			fi
			$vm1_exec -v 31 $player > vm1_output.tmp 2>&1
			$vm2_exec -v 31 $player > vm2_output.tmp 2>&1
			diff -y vm1_output.tmp vm2_output.tmp > diff_output.tmp
			printf "%s" "$player "
			if [ -s diff_output.tmp ]; then
				print_error "Booo!"
				printf "\n"	
				cat diff_output.tmp
			else
				print_ok "Good!"
				printf "\n"	
			fi
			[ $RUN_ASM -eq 1 ] && rm $player
		fi
	done
}

ASM="../corewar/corewar_resources/asm"
RUN_ASM=0

check_args $@
[ $RUN_ASM -eq 1 ] && shift
run_test $@
