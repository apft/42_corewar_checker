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
	printf "%s\n" "Usage: ./vm_checker.sh exec1 exec2 player"
	printf "%s\n" "  -exec   Path to executable"
	printf "%s\n" "  -player Player (.cor file)"
	exit
}

check_executable()
{
	if [ ! -f $1 ];then
		printf "%s\n" "Executable ($1) not found"
		exit
	fi
}

check_args()
{
	if [ $# -lt 3 ];then
		print_usage_and_exit
		exit
	fi
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
			$vm1_exec $player > vm1_output.tmp 2>&1
			$vm2_exec $player > vm2_output.tmp 2>&1
			diff vm1_output.tmp vm2_output.tmp > diff_output.tmp
			printf "%s" "$player "
			if [ -s diff_output.tmp ]; then
				print_error "Booo!"
				printf "\n"	
				cat diff_output.tmp
			else
				print_ok "Good!"
				printf "\n"	
			fi
		fi
	done
}

check_args $@

run_test $@
