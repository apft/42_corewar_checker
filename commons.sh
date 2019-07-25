#!/bin/bash

if [ -f colors.sh ]; then
	. colors.sh
fi

STATUS_SUCCESS=0
STATUS_TIMEOUT=2
STATUS_LEAKS=3
STATUS_ASM_FAILED=4
STATUS_SEGV=139

count_success=0
count_failure=0
count_timeout=0
count_leaks=0

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

create_filename()
{
	local name=$1
	local suffix=$2

	basename $name.$suffix.$(date "+%Y%M%d%H%M")
}

initialize_dir()
{
	for dir in $@
	do
		if [ ! -d $dir ]; then
			printf "Create directory $dir\n"
			mkdir $dir
		fi
	done
}

clean_dir()
{
	for dir in $@
	do
		[ -d $dir ] && rm -R $dir
	done
}

check_valid_file()
{
	for file in $@
	do
		if [ ! -f $file ]; then
			printf "${YELLOW}%s${RESET}\n" "File ($file) not found\n"
			return 1
		fi
	done
	return 0
}

get_basename()
{
	local output=""

	for file in $@
	do
		output+=`basename $file | tr -d '\n'`
		output+="  "
	done
	printf "$output" | sed 's/ +$//'
}

compute_column_width()
{
	local items=$@
	local width=0
	local length=0

	for item in $items
	do
		length=${#item}
		if [ $width -lt $length ]; then
			width=$length
		fi
	done
	echo $((width + 5))
}

cmd_check_leaks()
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
	return $STATUS_SUCCESS
}

check_segfault()
{
	local output=$1

	if grep -Ei "$0:.+segmentation fault" $output > /dev/null; then
		return $STATUS_SEGV
	fi
	return $STATUS_SUCCESS
}

get_status()
{
	local status=$1
	local output=$2
	local leak_file=$3

	[ $status -eq $STATUS_TIMEOUT ] && return $STATUS_TIMEOUT
	check_segfault $output || return $STATUS_SEGV
	if [ $CHECK_LEAKS -ne 0 ]; then
		check_leaks $leak_file
		[ $? -eq $STATUS_LEAKS ] && return $STATUS_LEAKS
	fi
	[ $status -ne $STATUS_SUCCESS ] && return $status
	return $STATUS_SUCCESS
}

print_status()
{
	if [ $1 -eq $STATUS_SUCCESS ]; then
		printf "${GREEN}✔ $RESET"
	else
		printf "${RED}✗ $RESET"
	fi
}

print_summary()
{
	local nbr_of_players=$1
	printf "Success: ${GREEN}%4d/%d${RESET}\n" $count_success $nbr_of_players
	printf "Failure: ${RED}%4d/%d${RESET}\n" $count_failure $nbr_of_players
	if [ $CHECK_LEAKS -ne 0 ]; then
		printf "Leaks  : ${RED}%4d/%d${RESET}\n" $count_leaks $nbr_of_players
	fi
	if [ $KILL_TIMEOUT -ne 0 ]; then
		printf "Timeout: ${YELLOW}%4d/%d${RESET}\n" $count_timeout $nbr_of_players
	fi
}
